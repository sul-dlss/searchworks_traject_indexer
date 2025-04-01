# frozen_string_literal: true

module CallNumbers
  class SudocShelfkey < ShelfkeyBase
    DELIMITER_PRECEDENCE = {
      ':' => '10',
      '.' => '11',
      ';' => '12',
      '/' => '14',
      '+' => '15'
    }.freeze

    TYPE_PRECEDENCE = {
      alphabetic: '20',
      year: '30',
      numeric: '40'
    }.freeze

    def forward
      [
        'sudoc',
        pad(parsed[:agency]&.downcase, by: 3),
        pad_all_digits(parsed[:class_num]),
        normalize_remainder(parsed[:remainder])
      ].filter_map(&:presence).join(' ').strip
    end

    private

    def parsed
      @parsed ||= /
        ^\s*(?:\[[^\]]+\]\s*)?
        (?<agency>[A-Z]+)\s*
        (?<class_num>\d+)
        (?<remainder>.*)
      /ix.match(base_call_number)

      @parsed ||= {}
    end

    def normalize_remainder(remainder)
      return '' if remainder.empty?

      tokens = tokenize_remainder(remainder)
      normalized_tokens = []

      previous_token = nil
      tokens.each do |token|
        normalized_tokens << normalize_token(token, previous_token)
        previous_token = token
      end

      normalized_tokens.compact.join(' ')
    end

    def tokenize_remainder(remainder)
      remainder.scan(%r{[:.;/+]|[^:.;/+]+})
    end

    def normalize_token(token, previous_token = nil)
      return nil if token =~ /^\s*$/

      if DELIMITER_PRECEDENCE.key?(token)
        DELIMITER_PRECEDENCE[token]
      elsif token =~ /^[a-zA-Z\-]+$/
        "#{TYPE_PRECEDENCE[:alphabetic]} #{token.downcase}"
      elsif token =~ /^\d+-\d+$/
        normalize_number_range(token, previous_token)
      elsif token =~ /^\d{3,4}$/
        normalize_potential_year(token, previous_token)
      elsif token =~ /^\d+$/
        "#{TYPE_PRECEDENCE[:numeric]} #{pad_all_digits(token)}"
      else
        "#{TYPE_PRECEDENCE[:alphabetic]} #{pad_all_digits(token)}"
      end
    end

    def normalize_potential_year(token, previous_token)
      if possible_year?(token, previous_token)
        "#{TYPE_PRECEDENCE[:year]} #{four_digit_year_string(token)}"
      else
        "#{TYPE_PRECEDENCE[:numeric]} #{pad_all_digits(token)}"
      end
    end

    def normalize_number_range(token, previous_token)
      range_start, range_end = token.split('-')
      if year_range?(range_start, range_end)
        "#{TYPE_PRECEDENCE[:year]} #{four_digit_year_string(range_start)}-#{four_digit_year_string(range_end, range_start)}"
      elsif possible_year?(range_start, previous_token)
        "#{TYPE_PRECEDENCE[:year]} #{four_digit_year_string(range_start)}-#{TYPE_PRECEDENCE[:numeric]} #{pad_all_digits(range_end)}"
      else
        "#{TYPE_PRECEDENCE[:numeric]} #{pad_all_digits(token)}"
      end
    end

    def possible_year?(token, previous_token = nil)
      return false unless previous_token && ([':', '/'].include?(previous_token))

      val = token.to_i

      # Oldest SUDOC year may be 1841?
      # Prior to 2000, years were sometimes written as three digits.
      return true if val >= 841 && val <= 999

      return true if val >= 1841 && val <= Time.now.year

      false
    end

    def four_digit_year_string(year_string, basis = '1000')
      return year_string if year_string.length == 4
      return nil unless year_string.length.positive? && year_string.length < 4

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
