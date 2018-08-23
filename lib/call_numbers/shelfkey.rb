require 'call_numbers/shelfkey_base'

module CallNumbers
  class Shelfkey < ShelfkeyBase
    def to_shelfkey
      [
        call_number.scheme,
        (self.class.pad(klass.downcase, by: 3, character: ' ') if klass),
        "#{self.class.pad(klass_number, by: 4, direction: :left)}#{self.class.pad(klass_decimal ? klass_decimal : '.')}",
        self.class.pad_all_digits(doon1),
        self.class.pad_cutter(cutter1),
        self.class.pad_all_digits(doon2),
        self.class.pad_cutter(cutter2),
        self.class.pad_cutter(cutter3),
        (folio || '').downcase.strip,
        rest_with_serial_behavior
      ].compact.reject(&:empty?).join(' ').strip
    end

    private

    def rest_with_serial_behavior
      return unless rest && !rest.empty?
      return self.class.pad_all_digits(rest) unless serial
      self.class.reverse(self.class.pad_all_digits(rest)).strip.ljust(50, '~')
    end
  end
end
