# frozen_string_literal: true

require 'active_support/core_ext/module/delegation'
require 'i18n'

module CallNumbers
  class ShelfkeyBase
    CUTTER_ROUNDING = 6
    PADDING = 6
    FORWARD_CHARS = ('0'..'9').to_a + ('a'..'z').to_a

    CHAR_MAP = FORWARD_CHARS.zip(FORWARD_CHARS.reverse).to_h.merge(
      '.' => '}',
      '{' => ' ',
      '|' => ' ',
      '}' => ' ',
      '~' => ' ',
      ' ' => '~',
      '/' => '~',
      ':' => '~',
      '-' => '~'
    )

    attr_reader :base_call_number, :volume_info, :serial, :scheme

    def initialize(base_call_number, volume_info = '', serial: false, scheme: nil)
      @base_call_number = base_call_number
      @volume_info = volume_info
      @serial = serial
      @scheme = scheme
    end

    def forward
      raise NotImplementedError
    end

    def reverse
      self.class.reverse(forward).strip.ljust(50, '~')
    end

    # Unit tests inidcate that serial deweys don't get reversed years justified with tildes
    def volume_info_with_serial_behavior
      return if volume_info.blank?
      return self.class.pad_all_digits(volume_info) unless serial

      self.class.reverse(self.class.pad_all_digits(volume_info)).strip.ljust(50, '~')
    end

    delegate :pad, :pad_all_digits, :pad_cutter, :expand_two_digit_year, :replace_roman_numerals, to: :class

    class << self
      def reverse(value)
        value.chars.map do |char|
          char = I18n.transliterate(char).downcase
          if CHAR_MAP[char]
            CHAR_MAP[char]
          elsif /\w/.match?(char)
            # if it's not a character in our map, it's probably a non-latin, non-digit
            # which ordinarily sorts after 0-9, A-Z, so sort it first.
            '0'
          else
            # and if it is not a letter or a digit, sort it last
            '~'
          end
        end.join('')
      end

      def pad_all_digits(value, by: PADDING)
        return unless value
        return value.downcase.strip unless value[/\d+/]

        value.downcase.gsub(/\d+/) do |val|
          pad(val, by:, direction: :left)
        end.strip
      end

      def pad_cutter(cutter)
        return unless cutter

        cutter = cutter.downcase.sub(/^\./, '') # downcase and remove opening period
        # Round numbers to 6
        cutter.sub!(/(\d+)/, round_cutter_number(cutter[/\d+/])) if cutter[/\d+/].length > CUTTER_ROUNDING
        cutter.sub!(/(\d+)/, ".#{pad(cutter[/\d+/])}") # Pad numbers
        cutter.sub!(/([a-z]+)/, pad(cutter[/[a-z]+/], by: 2)) # Pad letters
        cutter
      end

      def pad(value, by: PADDING, direction: :right, character: '0')
        raise ArgumentError unless %i[left right].include?(direction.to_sym)

        value ||= ''

        by += 1 if value.start_with?('.') || value.end_with?('.') # add another number to the padding to account for

        case direction.to_sym
        when :right
          value.ljust(by, character)
        when :left
          value.rjust(by, character)
        end
      end

      def expand_two_digit_year(short_year_str, base_year_str)
        short_year = short_year_str.to_i
        base_year = base_year_str.to_i
        century = (base_year / 100) * 100
        if short_year < (base_year % 100)
          (century + 100 + short_year).to_s
        else
          (century + short_year).to_s
        end
      end

      def replace_roman_numerals(text)
        text.gsub(/(\s|^|\W)([MCDLXVI]+)(\s|$|\W)/i) do
          prefix = ::Regexp.last_match(1)
          roman = ::Regexp.last_match(2)
          suffix = ::Regexp.last_match(3)
          prefix + roman.r_to_i.to_s + suffix
        end
      end

      private

      # We are currently rounding the cutter numbers for parity with the sw-solrmarc
      # shelfkey logic.  We may want to revisit this in the future as we could
      # use larger padding here to account for larger cutters instead.
      def round_cutter_number(number, by: CUTTER_ROUNDING)
        "0.#{number}".to_f.round(by).to_s.sub(/^0\./, '')
      end
    end
  end
end
