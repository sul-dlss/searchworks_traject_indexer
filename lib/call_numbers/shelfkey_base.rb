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

    attr_reader :call_number

    def initialize(call_number)
      @call_number = call_number
    end

    def forward
      raise NotImplementedError
    end

    def reverse
      self.class.reverse(forward).ljust(50, '~')
    end

    # Unit tests inidcate that serial deweys don't get reversed years justified with tildes
    def volume_info_with_serial_behavior
      return if call_number.volume_info.blank?
      return self.class.pad_all_digits(call_number.volume_info) unless call_number.serial

      self.class.reverse(self.class.pad_all_digits(call_number.volume_info)).strip.ljust(50, '~')
    end

    delegate :pad, :pad_all_digits, :pad_cutter, to: :class

    class << self
      def reverse(value)
        value.chars.map do |char|
          char = I18n.transliterate(char).downcase
          if CHAR_MAP[char]
            CHAR_MAP[char]
          elsif char =~ /\w/
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
        raise ArugmentError unless %i[left right].include?(direction.to_sym)

        value ||= ''

        by += 1 if value.start_with?('.') || value.end_with?('.') # add another number to the padding to account for

        case direction.to_sym
        when :right
          value.ljust(by, character)
        when :left
          value.rjust(by, character)
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
