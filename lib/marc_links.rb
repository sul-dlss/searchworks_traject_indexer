# frozen_string_literal: true

module MarcLinks
  PROXY_REGEX = /stanford\.idm\.oclc\.org/

  class Processor
    attr_reader :link_field

    def field
      link_field
    end

    def initialize(link_field)
      @link_field = link_field
    end

    def as_h
      return unless link_host

      {
        version: '0.1',

        html: [%(<a title="#{link_title_html_escaped}" href="#{link_field_html_escaped}">#{link_text_html_escaped}</a>),
               "#{'(source: Casalini)' if link_is_casalini?}",
               (if additional_text
                  %( <span class="additional-link-text">#{additional_text_html_escaped}</span>)
                end)].compact.join(' '),
        text: [link_text_html_escaped, "#{'(source: Casalini)' if link_is_casalini?}",
               (if additional_text
                  " <span class='additional-link-text'>#{additional_text_html_escaped}</span>"
                end)].compact.join(' ').strip,

        stanford_only: stanford_only?,
        stanford_law_only: stanford_law_only?,

        link_text:,
        link_title:,
        additional_text:,
        href: field['u'],
        sort: purl_info['sort'],
        casalini: link_is_casalini?,

        fulltext: link_is_fulltext?,
        finding_aid: link_is_finding_aid?,
        managed_purl: link_is_managed_purl?,
        file_id: purl_info['file'],
        druid:,
        sfx: link_is_sfx?
      }
    end

    private

    def link_title_html_escaped
      CGI.escapeHTML(link_title.to_s)
    end

    def link_field_html_escaped
      CGI.escapeHTML(field['u'].to_s)
    end

    def link_text_html_escaped
      CGI.escapeHTML(link_text.to_s)
    end

    def additional_text_html_escaped
      CGI.escapeHTML(additional_text.to_s)
    end

    def link_is_casalini?
      (field['x'] && field['x'] == 'CasaliniTOC') ||
        (field.subfields.find { |sf| sf.code == 'z' && sf.value.match?(casalini_subz_regex) })
    end

    def link_is_sfx?
      field['u']&.match? Regexp.union(%r{^http://library.stanford.edu/sfx\?.+}, %r{^http://caslon.stanford.edu:3210/sfxlcl3\?.+})
    end

    # Parse a URI object to return the host of the URL in the "url" parameter if it's a proxied resoruce
    def link_host
      return if field['u'].nil?

      @link_host ||= begin
        # Not sure why I need this, but it fails on certain URLs w/o it.  The link printed still has character in it
        fixed_url = field['u'].gsub('^', '').strip
        link = URI.parse(fixed_url)

        return link.host unless PROXY_REGEX.match?(link.to_s) && link.to_s.include?('url=')

        proxy = CGI.parse(link.query.force_encoding(Encoding::UTF_8))
        return link.host unless proxy.key?('url')

        extracted_url = URI.extract(proxy['url'].first).first
        return link.host unless extracted_url

        URI.parse(extracted_url).host
      rescue URI::InvalidURIError
        return nil
      end
    end

    def link_text
      if field['x'] and field['x'] == 'CasaliniTOC'
        field['3']
      elsif /SDR-PURL/.match?(field['x'])
        purl_info['label']
      else
        sub3 = field['3']
        suby = field['y']
        !suby && !sub3 ? link_host : [sub3, suby].compact.join(' ')
      end
    end

    def subzs
      @subzs ||= field.select { |sf| sf.code == 'z' }.map(&:value).join(' ')
    end

    def link_title
      return '' if field['x'] and field['x'] == 'CasaliniTOC'

      return subzs if /SDR-PURL/.match?(field['x'])

      if stanford_affiliated_regex.match?(subzs)
        'Available to Stanford-affiliated users only'
      else
        subzs
      end
    end

    def additional_text
      return subzs if stanford_law_only?
      return unless stanford_only?

      subbed_title = subzs.gsub(stanford_affiliated_regex, '')
                          .gsub(casalini_subz_regex, '')
                          .strip
      subbed_title unless subbed_title.empty?
    end

    def purl_info
      return {} unless /SDR-PURL/.match?(field['x'])

      @purl_info ||= field.subfields.select do |subfield|
                       subfield.code == 'x'
                     end.map { |subfield| subfield.value.split(':', 2).map(&:strip) }.select { |x| x.length == 2 }.to_h
    end

    def link_is_fulltext?
      return !link_is_sfx? if field.tag == '956'

      resource_labels = ['table of contents', 'abstract', 'description', 'sample text']
      return false unless %w[0 1 3 4].include?(field.indicator2)

      # Similar logic exists in the mapping for the url_fulltext field in sirsi traject config.
      # They need to remain the same (or should be refactored to use the same code in the future)
      resource_labels.none? do |resource_label|
        "#{field['3']} #{field['z']}".downcase.include?(resource_label)
      end
    end

    def link_is_finding_aid?
      "#{field['3']} #{field['z']}".downcase.include?('finding aid')
    end

    def stanford_only?
      subzs.match?(stanford_affiliated_regex) || "#{field['3']} #{field['z']}".match?(stanford_affiliated_regex)
    end

    def stanford_law_only?
      subzs.match?(stanford_law_affiliated_regex)
    end

    def link_is_managed_purl?
      field['u'] && field['x'] && field['x'].match?(/SDR-PURL/)
    end

    def druid
      field['u'] && field['u'].gsub(%r{^https?://purl.stanford.edu/?}, '') if /purl.stanford.edu/.match?(field['u'])
    end

    def stanford_affiliated_regex
      Regexp.new(/available[ -]?to[ -]?stanford[ -]?affiliated[ -]?users[ -]?a?t?[:;.]?/i)
    end

    def casalini_subz_regex
      Regexp.new(/\(?source:?\s?casalini\)?/i)
    end

    def stanford_law_affiliated_regex
      /Available to Stanford Law School/i
    end
  end
end
