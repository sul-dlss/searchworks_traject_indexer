# frozen_string_literal: true

module CallNumbers
  class Shelfkey < ShelfkeyBase
    def to_shelfkey
      [
        call_number.scheme,
        (pad(klass.downcase, by: 3, character: ' ') if klass),
        [pad(klass_number, by: 4, direction: :left), pad(klass_decimal || '.')].join,
        pad_all_digits(doon1),
        pad_cutter(cutter1),
        pad_all_digits(doon2),
        pad_cutter(cutter2),
        pad_all_digits(doon3),
        pad_cutter(cutter3),
        (folio || '').downcase.strip,
        rest_with_serial_behavior
      ].compact.reject(&:empty?).join(' ').strip
    end

    private

    def rest_with_serial_behavior
      return unless rest
      return if rest.empty? && (call_number.scheme == 'lc' || call_number.scheme == 'dewey')
      return self.class.pad_all_digits(rest) unless serial

      self.class.reverse(self.class.pad_all_digits(rest)).strip.ljust(50, '~')
    end
  end
end
