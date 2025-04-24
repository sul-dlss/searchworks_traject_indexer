# frozen_string_literal: true

module CallNumbers
  class SudocShelfkey < ShelfkeyBase
    DELIMITER_PRECEDENCE = {
      ':' => 'a',
      ';' => 'b',
      '/' => 'c',
      '+' => 'd'
    }.freeze

    TYPE_PRECEDENCE = {
      year: 'q',
      alphabetic: 'r',
      numeric: 's'
    }.freeze

    def forward
      [
        'sudoc',
        pad(parsed[:agency]&.downcase, by: 3),
        pad_all_digits(parsed[:class_num]),
        normalize_remainder(parsed[:remainder]),
        volume_info_with_serial_behavior
      ].filter_map(&:presence).join(' ').strip
    end

    private

    def parsed
      @parsed ||= /
        ^\s*(?:\[[^\]]+\]\s*)?
        (?<agency>[A-Z]+)\s*
        (?<class_num>\d+)\.?
        (?<remainder>.*)
      /ix.match(base_call_number)

      @parsed ||= {}
    end

    # Remainder is the title number (e.g., "23" or "23/4") and the suffix
    def normalize_remainder(remainder)
      return nil unless remainder.present?

      remainder = normalize_remainder_periods(remainder.downcase)
      tokens = tokenize_remainder(remainder)
      previous_token = nil

      result = tokens.filter_map do |token|
        normalized_token = normalize_token(token, previous_token)
        previous_token = token
        normalized_token
      end.join(' ')

      terminate_remainder(result)
    end

    def tokenize_remainder(remainder)
      remainder.scan(%r{[:;/+\s]|[^:;/+\s]+})
    end

    def normalize_remainder_periods(remainder)
      remainder = remainder.gsub(/(\d+)\s*\.\s*(\d+)/, '\1 \2')
      remainder = remainder.gsub(/([a-z]+)\s*\.\s*(\d+)/i, '\1 \2')
      remainder = remainder.gsub(/(\d+)\s*\.\s*([a-z]+)/i, '\1 \2')
      remainder.tr('.', '')
    end

    # This assists reverse dealing with arbitrary length strings
    def terminate_remainder(remainder)
      "#{remainder} !"
    end

    def with_type_prefix(type, value)
      "#{TYPE_PRECEDENCE[type]}#{value}"
    end

    def normalize_token(token, previous_token = nil)
      return nil if /^\s*$/.match?(token)

      case token
      when ->(t) { DELIMITER_PRECEDENCE.key?(t) }
        DELIMITER_PRECEDENCE[token]
      when /^\d+-\d+$/
        normalize_number_range(token, previous_token)
      when /^\d+-[a-z]+$/, /^[a-z]+-\d+$/
        normalize_mixed_range(token, previous_token)
      when /^\d{3,4}$/
        normalize_potential_year(token, previous_token)
      when /^\d+$/
        with_type_prefix(:numeric, pad_all_digits(token))
      else
        with_type_prefix(:alphabetic, pad_all_digits(token))
      end
    end

    def normalize_potential_year(token, previous_token)
      if possible_year?(token, previous_token)
        with_type_prefix(:year, four_digit_year_string(token))
      else
        with_type_prefix(:numeric, pad_all_digits(token))
      end
    end

    def normalize_mixed_range(token, previous_token)
      range_start, range_end = token.split('-')
      [normalize_token(range_start, previous_token), normalize_token(range_end, '-')].join
    end

    def normalize_number_range(token, previous_token)
      range_start, range_end = token.split('-')
      if year_range?(range_start, range_end)
        with_type_prefix(:year, "#{four_digit_year_string(range_start)}*#{four_digit_year_string(range_end, range_start)}")
      elsif possible_year?(range_start, previous_token)
        [with_type_prefix(:year, four_digit_year_string(range_start)), with_type_prefix(:numeric, pad_all_digits(range_end))].join
      else
        [with_type_prefix(:numeric, pad_all_digits(range_start)), with_type_prefix(:numeric, pad_all_digits(range_end))].join
      end
    end

    def possible_year?(token, previous_token = nil)
      return false unless previous_token && ([':', '/'].include?(previous_token))

      val = token.to_i

      # Oldest SUDOC year may be 1841?
      # Prior to 2000, years were sometimes written as three digits.
      return true if val.between?(841, 999)

      return true if val.between?(1841, Time.now.year)

      false
    end

    def four_digit_year_string(year_string, basis = '1000')
      return year_string if year_string.length == 4
      return nil unless year_string.length.between?(1, 3)

      basis[0..-(year_string.length + 1)] + year_string
    end

    def year_range?(start, finish)
      return false unless possible_year?(start)

      end_year_string = four_digit_year_string(finish, start)
      return false unless end_year_string

      return true if start.to_i < end_year_string.to_i

      false
    end
  end
end
