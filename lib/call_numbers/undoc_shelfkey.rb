# frozen_string_literal: true

module CallNumbers
  class UndocShelfkey < ShelfkeyBase
    def forward
      parts = ['undoc'] + normalize_base_call_number + [volume_info_with_serial_behavior]
      parts.filter_map(&:presence).join(' ').strip
    end

    private

    def components
      @components ||= begin
        parts = base_call_number.split(%r{/(?![^(]*\))})

        parts.map do |part|
          part = normalize_periods(part)
          UndocCallnumberComponent.new(part.strip)
        end
      end
    end

    def normalize_base_call_number
      components.each_with_index.map do |component, index|
        next_component = components[index + 1] if index + 1 < components.size
        part = index > 1 || !component.symbol? ? replace_roman_numerals(component.value) : component.value
        part = normalize_parens(part)
        part = normalize_slashes(part)
        part = expand_two_digit_year(part, '1945') if component.expandable_year? && next_component&.possible_sessional_info? && !four_digit_year?
        pad_all_digits(part)
      end
    end

    def normalize_periods(part)
      part = part.gsub(/(\d+)\s*\.\s*(\d+)/, '\1 \2')
      part = part.gsub(/([a-z]+)\s*\.\s*(\d+)/i, '\1\2')
      part = part.gsub(/([a-z]+)\s*\.\s*([a-z]+)/i, '\1\2')
      part = part.gsub(/(\d+)\s*\.\s*([a-z]+)/i, '\1\2')
      part.tr('.', '')
    end

    def normalize_parens(part)
      part.gsub(/\s*\(\s*/, ' ').gsub(/\s*\)\s*/, ' ')
    end

    def normalize_slashes(part)
      part.split('/').map(&:strip).join(' ')
    end

    def four_digit_year?
      components.any?(&:four_digit_year_or_range?)
    end

    class UndocCallnumberComponent
      attr_reader :value

      def initialize(value)
        @value = value
      end

      def expandable_year?
        value.match?(/^\d{2}$/)
      end

      def four_digit_year_or_range?
        value.match?(/^\d{4}(?:-\d{2,4})?$/)
      end

      def possible_sessional_info?
        value.match?(/^\d+$/)
      end

      def symbol?
        value.match?(/^[A-Z]+$/)
      end
    end
  end
end
