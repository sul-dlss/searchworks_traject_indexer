# frozen_string_literal: true

module CallNumbers
  class CaldocShelfkey < ShelfkeyBase
    def forward
      [
        'caldoc',
        parsed[:caldoc_letter]&.downcase,
        pad(parsed[:caldoc_number], by: 4, direction: :left),
        pad_all_digits(parsed[:sub_agency]),
        pad_all_digits(parsed[:book1]),
        pad_all_digits(parsed[:book2]),
        pad(parsed[:year], by: 4, direction: :left),
        pad(year_range_end, by: 4, direction: :left),
        pad(accession_number, by: 4, direction: :left),
        pad_all_digits(parsed[:rest]),
        volume_info_normalized
      ].filter_map(&:presence).join(' ').strip
    end

    def volume_info_normalized
      return unless volume_info.present?

      replace_roman_numerals(volume_info).downcase
    end

    private

    def parsed
      @parsed ||= %r{
        ^.*CALIF\s+
        (?<caldoc_letter>[A-Z])\s*
        (?<caldoc_number>\d{3,4})\s*
        (?<sub_agency>[A-Z]\d{1,2})?\s*
        \.*\s*
        (?<book1>[A-Z]\d{1,4}[A-Z]*)\s*
        (?<book2>[A-Z]\d{1,4})?\s*
        (?<year>\d{4}?)(?:[-/](?<year2>\d{4}|(?:\d{2})))?\s*
        (?<rest>.*)
     }xi.match(base_call_number)

      @parsed ||= {}
    end

    def year_range_end
      @year_range_end ||= calculate_year_end
    end

    def calculate_year_end
      return nil unless parsed[:year2]

      if parsed[:year2].length == 2
        expand_two_digit_year(parsed[:year2], parsed[:year])
      else
        parsed[:year2]
      end
    end

    def accession_number
      if (number_match = parsed[:rest]&.match(/NO\.?\s*(\d+)/))
        number_match[1]
      elsif (roman_match = parsed[:rest]&.match(/NO\.?\s*([MCDLXVI]+)/))
        roman_match[1].r_to_i.to_s
      end
    end
  end
end
