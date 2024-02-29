# frozen_string_literal: true

require 'active_support/core_ext/module/delegation'
require 'i18n'

module CallNumbers
  class ShelfkeyBase
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

    def to_shelfkey
      raise NotImplementedError
    end

    def to_reverse_shelfkey(omit_volume_info: false)
      self.class.reverse(to_shelfkey(omit_volume_info:)).ljust(50, '~')
    end

    def volume_info_with_serial_behavior
      return call_number.volume_info&.downcase&.strip unless call_number.volume_info&.match?(/\d+/)

      # prefix all numbers with the count of digits (and the count of digits of the count) so they sort lexically
      sortable_volume_info = call_number.volume_info.downcase.gsub(/\d+/) do |val|
        val.length.to_s.length.to_s + val.length.to_s + val
      end

      if serial
        self.class.reverse(sortable_volume_info).strip.ljust(50, '~')
      else
        sortable_volume_info
      end
    end

    delegate :pad, :pad_all_digits, to: :class

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
    end
  end
end
