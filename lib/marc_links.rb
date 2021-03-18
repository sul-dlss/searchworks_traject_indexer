module MarcLinks
  PROXY_REGEX = /stanford\.idm\.oclc\.org/

  class Processor
    attr_reader :link_field

    def initialize(link_field)
      @link_field = link_field
    end
    def as_h
      link = process_link(link_field)
      if link
        {
          html: ["<a title='#{link[:title]}' href='#{link[:href]}'>#{link[:text]}</a>", "#{'(source: Casalini)' if link[:casalini_toc]}", (" #{link[:additional_text]}" if link[:additional_text])].compact.join(' '),
          text: [link[:text], "#{'(source: Casalini)' if link[:casalini_toc]}", " #{link[:additional_text] if link[:additional_text]}"].compact.join(' ').strip,
          href: link[:href],
          fulltext: link_is_fulltext?(link_field),
          stanford_only: stanford_only?(link),
          finding_aid: link_is_finding_aid?(link_field),
          managed_purl: link_is_managed_purl?(link),
          file_id: file_id(link_field),
          druid: druid(link),
          sort: link[:sort],
          sfx: link_is_sfx?(link_field)
        }
      end
    end

    private

    def link_is_sfx?(link_field)
      link_field['u']&.match? Regexp.union(%r{^http://library.stanford.edu/sfx\?.+}, %r{^http://caslon.stanford.edu:3210/sfxlcl3\?.+})
    end

    def file_id(link_field)
      return unless link_field['x']
      subxs = link_field.subfields.select do |subfield|
        subfield.code == 'x'
      end

      file_id_value = subxs.find do |subx|
        subx.value.start_with?('file:')
      end&.value

      file_id_value.gsub('file:', '') if file_id_value
    end

    # Parse a URI object to return the host of the URL in the "url" parameter if it's a proxied resoruce
    def link_host(link)
      return link.host unless link.to_s =~ PROXY_REGEX && link.to_s.include?('url=')
      proxy = CGI.parse(link.query.force_encoding(Encoding::UTF_8))
      return link.host unless proxy.key?('url')

      extracted_url = URI.extract(proxy['url'].first).first
      return link.host unless extracted_url
      URI.parse(extracted_url).host
    end

    def process_link(field)
      unless field['u'].nil?
        # Not sure why I need this, but it fails on certain URLs w/o it.  The link printed still has character in it
        fixed_url = field['u'].gsub("^","").strip
        url = URI.parse(fixed_url)
        sub3 = nil
        subz = []
        suby = nil
        field.each{|subfield|
          if subfield.code == "3"
            sub3 = subfield.value
          elsif subfield.code == "z"
            subz << subfield.value
          elsif subfield.code == "y"
            suby = subfield.value
          end
        }

        if field["x"] and field["x"] == "CasaliniTOC"
          {:text=>field["3"],
           :title=>"",
           :href=>field["u"],
           :casalini_toc => true,
           :managed_purl => (field["u"] && field['x'] =~ /SDR-PURL/)
          }
        elsif field['x'] && field['x'] =~ /SDR-PURL/
          subxes = field.subfields.select { |subfield| subfield.code == 'x' }.map { |subfield| subfield.value.split(':', 2).map(&:strip) }.select { |x| x.length == 2 }.to_h

          link_text = subxes['label'] unless subxes['label'].nil?
          sort = subxes['sort']

          title = subz.join(' ') unless subz.empty?
          if title =~ stanford_affiliated_regex && !(subbed_title = title.gsub(stanford_affiliated_regex, '')).empty?
            additional_text = "<span class='additional-link-text'>#{subbed_title}</span>".html_safe
          end

          {
            text: link_text,
            title: title,
            href: field['u'],
            casalini_toc: false,
            additional_text: additional_text,
            sort: sort,
            managed_purl: true,
            file_id: subxes['file']
          }
        else
          link_text = (!suby && !sub3) ? link_host(url) : [sub3, suby].compact.join(' ')
          title = subz.join(" ")
          additional_text = nil
          if title =~ stanford_affiliated_regex
            subbed_title = title.gsub(stanford_affiliated_regex, '')
            additional_text = "<span class='additional-link-text'>#{subbed_title}</span>" unless subbed_title.empty?
            title = "Available to Stanford-affiliated users only" unless field['x'] && field['x'] =~ /SDR-PURL/
          elsif title =~ stanford_law_affiliated_regex
            additional_text = "<span class='additional-link-text'>#{title}</span>"
          end
          {:text=>link_text,
           :title=> title,
           :href=>field["u"],
           :casalini_toc => false,
           :additional_text => additional_text
          }
        end
      end
      rescue URI::InvalidURIError
        return nil
    end

    def link_is_fulltext?(field)
      return !link_is_sfx?(field) if field.tag == '956'

      resource_labels = ["table of contents", "abstract", "description", "sample text"]
      return false unless %w[0 1].include?(field.indicator2)

      # Similar logic exists in the mapping for the url_fulltext field in sirsi traject config.
      # They need to remain the same (or should be refactored to use the same code in the future)
      resource_labels.each do |resource_label|
        return false if "#{field['3']} #{field['z']}".downcase.include?(resource_label)
      end

      true
    end

    def link_is_finding_aid?(field)
      "#{field['3']} #{field['z']}".downcase.include?('finding aid')
    end

    def stanford_only?(link)
      [link[:text], link[:title]].join.downcase =~ stanford_affiliated_regex
    end

    def link_is_managed_purl?(link)
      link[:managed_purl]
    end

    def druid(link)
      link[:href].gsub(%r{^https?:\/\/purl.stanford.edu\/?}, '') if link[:href] =~ /purl.stanford.edu/
    end

    def stanford_affiliated_regex
      Regexp.new(/available[ -]?to[ -]?stanford[ -]?affiliated[ -]?users[ -]?a?t?[:;.]?/i)
    end

    def stanford_law_affiliated_regex
      /Available to Stanford Law School/i
    end
  end
end
