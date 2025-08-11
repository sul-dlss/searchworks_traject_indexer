# frozen_string_literal: true

CONTENT_ADVICE_LABEL = 'Content advice'
module Traject
  module MarcUtils
    def extract_marc_and_prefer_non_alternate_scripts(spec, options = {})
      lambda do |record, accumulator, context|
        extract_marc(spec, options.merge(alternate_script: false)).call(record, accumulator, context)
        if accumulator.empty?
          extract_marc(spec, options.merge(alternate_script: :only)).call(record, accumulator,
                                                                          context)
        end
      end
    end

    def clean_facet_punctuation(value)
      new_value = value.gsub(/^[%*]/, '') # begins with percent sign or asterisk
                       .gsub(/\({2,}+/, '(') # two or more open parentheses
                       .gsub(/\){2,}+/, ')') # two or more close parentheses
                       .gsub(/!{2,}+/, '!') #  two or more exlamation points
                       .gsub(/\s+/, ' ') # one or more spaces

      Utils.balance_parentheses(new_value)
    end

    # Custom method for traject's trim_punctuation
    # https://github.com/traject/traject/blob/5754e3c0c207d461ca3a98728f7e1e7cf4ebbece/lib/traject/macros/marc21.rb#L227-L246
    # Does the same except removes trailing period when preceded by at
    # least four letters instead of three.
    def trim_punctuation_custom(str, trailing_period_regex = nil)
      return str unless str

      trailing_period_regex ||= /( *[A-Za-z]{4,}|[0-9]{3}|\)|,)\. *\Z/

      previous_str = nil
      until str == previous_str
        previous_str = str
        # If something went wrong and we got a nil, just return it
        # trailing: comma, slash, semicolon, colon (possibly preceded and followed by whitespace)
        str = str.sub(%r{ *[ \\,/;:] *\Z}, '')

        # trailing period if it is preceded by at least four letters (possibly preceded and followed by whitespace)
        str = str.gsub(trailing_period_regex, '\1')

        # trim any leading or trailing whitespace
        str.strip!
      end

      str
    end

    def trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff(str)
      previous_str = nil
      until str == previous_str
        previous_str = str

        str = str.strip.gsub(%r{ *([,/;:])$}, '')
                 .sub(/(\w\w)\.$/, '\1')
                 .sub(/(\p{L}\p{L})\.$/, '\1')
                 .sub(/(\w\p{InCombiningDiacriticalMarks}?\w\p{InCombiningDiacriticalMarks}?)\.$/, '\1')

        # single square bracket characters if they are the start and/or end
        #   chars and there are no internal square brackets.
        str = str.sub(/\A\[?([^\[\]]+)\]?\Z/, '\1')
        str = str.delete_prefix('[') if str.index(']').nil? # no closing bracket
        str = str.sub(/\]\Z/, '') if str.index('[').nil? # no opening bracket

        str
      end

      str
    end

    def get_marc_vernacular(marc, original_field)
      return_text = []
      link = parse_linkage(original_field)
      return unless link[:number]

      marc.select { |f| link[:tag] == f.tag && parse_linkage(f)[:number] == link[:number] }.each do |field|
        field.each do |sub|
          next if Constants::EXCLUDE_FIELDS.include?(sub.code) || sub.code == '4'

          return_text << sub.value
        end
      end

      return_text.join(' ') unless return_text.empty?
    end

    ##
    # Originally cribbed from Traject::Marc21Semantics.marc_sortable_title, but by
    # using algorithm from StanfordIndexer#getSortTitle.
    def extract_sortable_title(fields, record)
      java7_punct = '!"#$%&\'()*+,-./:;<=>?@[\]^_`{|}~\\'
      Traject::MarcExtractor.new(fields, separator: false,
                                         alternate_script: false).collect_matching_lines(record) do |field, spec, extractor|
        subfields = extractor.collect_subfields(field, spec).compact

        if subfields.empty? && field['k']
          # maybe an APPM archival record with only a 'k'
          subfields = [field['k']]
        end
        if subfields.empty?
          # still? All we can do is bail, I guess
          return nil
        end

        non_filing = field.indicator2.to_i
        subfields[0] = subfields[0].slice(non_filing..-1) if non_filing < subfields[0].length - 1
        subfields.map { |x| x.delete(java7_punct) }.map(&:strip).join(' ')
      end.first
    end

    def works_struct(record, tags, indicator2: nil, link_codes: %w[a d f k l m n o p r s t].freeze,
                     text_codes: %w[h i x 3].freeze)
      Traject::MarcExtractor.cached(tags).collect_matching_lines(record) do |field, _spec, _extractor|
        next if %w[700 710 711].include?(field.tag) && (!field['t'] || field['t'].empty?)

        result = {
          before: [],
          inside: [],
          after: []
        }

        subfields_before = field.subfields.take_while { |subfield| !link_codes.include?(subfield.code) }
        subfields_after = field.subfields.reverse.take_while { |subfield| !link_codes.include?(subfield.code) }.reverse

        result[:before] = subfields_before.select do |subfield|
          text_codes.include?(subfield.code)
        end

        result[:inside] = field.subfields.slice(subfields_before.length..(-1 * (subfields_after.length + 1)))

        result[:after] = subfields_after.select do |subfield|
          text_codes.include?(subfield.code)
        end

        {
          link: result[:inside].map(&:value).join(' '),
          search: result[:inside].reject { |subfield| text_codes.include?(subfield.code) }.map(&:value).join(' '),
          pre_text: result[:before].map(&:value).join(' '),
          post_text: result[:after].map(&:value).join(' '),
          authorities: field.subfields.select { |x| x.code == '0' }.map(&:value),
          rwo: field.subfields.select { |x| x.code == '1' }.map(&:value)
        }
      end
    end

    POST_TEXT_SUBFIELDS = %w[e 4].freeze
    def linked_author_struct(record, tag)
      Traject::MarcExtractor.cached(tag).collect_matching_lines(record) do |field, _spec, _extractor|
        subfields = field.subfields.reject { |subfield| (Constants::EXCLUDE_FIELDS + ['7']).include?(subfield.code) }
        {
          link: subfields.select { |subfield| linked?(tag, subfield) }.map(&:value).join(' '),
          search: subfields.select do |subfield|
                    linked?(tag, subfield)
                  end.reject { |subfield| subfield.code == 't' }.map(&:value).join(' '),
          post_text: subfields.reject do |subfield|
                       subfield.code == 'i'
                     end.select do |subfield|
                       POST_TEXT_SUBFIELDS.include?(subfield.code) || !linked?(tag, subfield)
                     end.each do |subfield|
                       if subfield.code == '4'
                         subfield.value = Constants::RELATOR_TERMS[subfield.value]
                       end
                     end.filter_map(&:value).join(' '),
          authorities: field.subfields.select { |x| x.code == '0' }.map(&:value),
          rwo: field.subfields.select { |x| x.code == '1' }.map(&:value)
        }.reject { |_k, v| v.empty? }
      end
    end

    def linked_contributors_struct(record)
      contributors = []
      vern_fields = []

      Traject::MarcExtractor.cached('700:710:711:720', alternate_script: :only).each_matching_line(record) do |f|
        vern_fields << f if !f['t'] || f['t'].empty?
      end

      Traject::MarcExtractor.cached('700:710:711:720',
                                    alternate_script: false).collect_matching_lines(record) do |field, _spec, _extractor|
        if !field['t'] || field['t'].empty?
          link = parse_linkage(field)
          vern_field = vern_fields.find { |f| parse_linkage(f)[:number] == link[:number] } if field['6']

          contributor = assemble_contributor_data_struct(field)
          contributor[:vern] = assemble_contributor_data_struct(vern_field) if vern_field

          contributors << contributor
        end
      end

      vern_fields.each do |field, _spec, _extractor|
        link = parse_linkage(field)
        next unless link[:number] == '00'

        contributors << {
          vern: assemble_contributor_data_struct(field)
        }
      end

      contributors
    end

    def parse_linkage(field)
      return {} unless field && field['6']

      tag_and_number, script_id, field_orientation = field['6'].split('/')

      tag, number = tag_and_number.split('-', 2)

      { tag:, number:, script_id:, field_orientation: }
    end

    def assemble_contributor_data_struct(field)
      link_text = []
      relator_text = []
      extra_text = []
      before_text = []
      field.each do |subfield|
        next if (Constants::EXCLUDE_FIELDS + ['7']).include?(subfield.code)

        if subfield.code == 'e'
          relator_text << subfield.value
        elsif subfield.code == '4'
          relator_text << Constants::RELATOR_TERMS[subfield.value] if Constants::RELATOR_TERMS[subfield.value]
        elsif field.tag == '711' && subfield.code == 'j'
          extra_text << subfield.value
        elsif subfield.code != 'e' and subfield.code != '4'
          link_text << subfield.value
        end
      end

      {
        link: link_text.join(' '),
        search: link_text.join(' '),
        pre_text: before_text.join(' '),
        post_text: relator_text.join(' ') + extra_text.join(' '),
        authorities: field.subfields.select { |x| x.code == '0' }.map(&:value),
        rwo: field.subfields.select { |x| x.code == '1' }.map(&:value)
      }
    end

    def linked?(tag, subfield)
      case tag
      when '100', '110'
        !%w[e i 4].include?(subfield.code) # exclude 100/110 $e $i $4
      when '111'
        !%w[j 4].include?(subfield.code) # exclude 111 $j $4
      end
    end

    # Custom method cribbed from Traject::Macros::Marc21Semantics.marc_sortable_author
    # https://github.com/traject/traject/blob/0914a396306c2489a7e270f33793ca76665f8f19/lib/traject/macros/marc21_semantics.rb#L51-L88
    # Port from Solrmarc:MarcUtils#getSortableAuthor wasn't accurate
    # This method differs in that:
    #  245 field returned independent of 240 being present
    #  punctuation actually gets stripped
    #  subfields to use specified in passed parameter
    #  ensures record with no 1xx sorts after records with a 1xx by prepending UTF-8 max code point to title string
    def extract_sortable_author(author_fields, title_fields, record)
      punct = '!"#$%&\'()*+,-./:;<=>?@[\]^_`{|}~\\'
      onexx = Traject::MarcExtractor.cached(author_fields, alternate_script: false,
                                                           separator: false).collect_matching_lines(record) do |field, spec, extractor|
        non_filing = field.indicator2.to_i
        subfields = extractor.collect_subfields(field, spec).compact
        next if subfields.empty?

        subfields[0] = subfields[0].slice(non_filing..-1) if non_filing < subfields[0].length - 1
        subfields.map { |x| x.delete(punct) }.map(&:strip).join(' ')
      end.first

      onexx ||= Constants::MAX_CODE_POINT

      titles = title_fields.split(':').map do |title_spec|
        Traject::MarcExtractor.cached(title_spec, alternate_script: false,
                                                  separator: false).collect_matching_lines(record) do |field, spec, extractor|
          non_filing = field.indicator2.to_i
          subfields = extractor.collect_subfields(field, spec).compact
          next if subfields.empty?

          subfields[0] = subfields[0].slice(non_filing..-1) if non_filing < subfields[0].length - 1
          subfields.map { |x| x.delete(punct) }.map(&:strip).join(' ')
        end.first
      end

      title = titles.compact.join(' ')
      title = title.delete(punct).strip if title

      [onexx, title].compact.reject(&:empty?).join(' ')
    end

    # # publication dates
    def clean_date_string(value)
      value = value.strip
      valid_year_regex = /(?:20|19|18|17|16|15|14|13|12|11|10|09|08|07|06|05)[0-9][0-9]/

      # some nice regular expressions looking for years embedded in strings
      matches = [
        /^(#{valid_year_regex})\D{0,2}$/,
        /\[(#{valid_year_regex})\]/,
        /^\[?[©Ⓟcp](#{valid_year_regex})\D?$/,
        /i\. ?e\. ?(#{valid_year_regex})\D?/,
        /\[(#{valid_year_regex})\D.*\]/
      ].map { |r| r.match(value)&.captures&.first }

      best_match = matches.compact.first if matches

      # reject BC dates altogether.
      return if value =~ /[0-9]+ B\.?C\.?/i

      # else if (bracesAround19Matcher.find())
      #   cleanDate = bracesAround19Matcher.group().replaceAll("\\[", "").replaceAll("\\]", "");
      # else if (unclearLastDigitMatcher.find())
      #   cleanDate = unclearLastDigitMatcher.group().replaceAll("[-?]", "0");

      # if a year starts with an l instead of a 1
      best_match ||= ("1#{Regexp.last_match(1)}" if value =~ /l((?:9|8|7|6|5)\d{2,2})\D?/)
      # brackets around the century, e.g. [19]56
      best_match ||= ("19#{Regexp.last_match(1)}" if value =~ /\[19\](\d\d)\D?/)
      # uncertain last digit
      best_match ||= ("#{Regexp.last_match(1)}0" if value =~ /((?:20|19|18|17|16|15)[0-9])[-?]/)

      # is the date no more than 1 year in the future?
      best_match.to_i.to_s if best_match.to_i.between?(500, Time.now.year + 1)
    end

    def clean_marc_008_date(year, u_replacement: '0')
      return unless /(\d{4}|\d{3}[u-])/.match?(year)

      year = year.gsub(/[u-]$/, u_replacement)
      return unless (500..(Time.now.year + 10)).cover? year.to_i

      year.to_i.to_s
    end

    def marc_008_date(byte6values, byte_range, u_replacement)
      lambda do |record, accumulator|
        Traject::MarcExtractor.new('008', first: true).collect_matching_lines(record) do |field, _spec, _extractor|
          if byte6values.include? field.value[6]
            year = clean_marc_008_date(field.value[byte_range], u_replacement:)
            accumulator << year if year
          end
        end
      end
    end

    # @return [Array]
    def get_unmatched_vernacular(marc, tag, label = '')
      return [] unless marc['880']

      fields = []

      marc.select { |f| f.tag == '880' }.each do |field|
        text = []
        link = parse_linkage(field)

        next unless link[:number] == '00' && link[:tag] == tag

        content_advice = (tag == '520' && field.indicator1 == '4')
        next if content_advice != (label == CONTENT_ADVICE_LABEL)

        field.each do |sub|
          next if Constants::EXCLUDE_FIELDS.include?(sub.code)

          text << sub.value
        end

        fields << text.join(' ') unless text.empty?
      end

      fields
    end

    # INDEX-142 NOTE: Lane Medical adds (Print) or (Digital) descriptors to their ISSNs
    # so need to account for it in the pattern match below
    def issn_pattern
      /^\d{4}-\d{3}[X\d]\D*$/
    end

    def extract_isbn(value)
      value = value.strip
      isbn10_pattern = /^\d{9}[\dX].*/
      isbn13_pattern = /^(978|979)\d{9}[\dX].*/
      isbn13_any = /^\d{12}[\dX].*/

      if value&.match?(isbn13_pattern)
        value[0, 13]
      elsif value =~ isbn10_pattern && value !~ isbn13_any
        value[0, 10]
      end
    end

    def split_toc_chapters(value)
      formatted_chapter_regexes = [
        /[^\S]--[^\S]/, # this is the normal, expected MARC delimiter
        /      /, # but a bunch of eResources like to use whitespace
        /--[^\S]/, # or omit the leading whitespace
        /[^\S]\.-[^\S]/, # or a .-
        /(?=(?:Chapter|Section|Appendix|Part|v\.) \d+[:.-]?\s+)/i, # and sometimes not even that; here are some common patterns that suggest chapters
        /(?=(?:Appendix|Section|Chapter) [XVI]+[.-]?)/i,
        /(?=[^\d](?:\d+[:.-]\s+))/i, # but sometimes it's just a number with something after it
        /(?=(?:\s{2,}\d+\s+))/i # or even just a number with a little extra whitespace in front of it
      ]
      formatted_chapter_regexes.each do |regex|
        chapters = value.split(regex).filter_map { |w| w.strip unless w.strip.empty? }
        # if the split found a match and actually split the string, we are done
        return chapters if chapters.length > 1
      end
      [value]
    end
  end
end
