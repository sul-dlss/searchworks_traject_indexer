require 'call_numbers/shelfkey_base'

module CallNumbers
  class Shelfkey < ShelfkeyBase
    def to_shelfkey
      [
        call_number.scheme,
        self.class.pad(klass.downcase, by: 3, character: ' '),
        "#{self.class.pad(klass_number, by: 4, direction: :left)}#{self.class.pad(klass_decimal ? klass_decimal : '.')}",
        self.class.pad_all_digits(doon1),
        self.class.pad_cutter(cutter1),
        self.class.pad_all_digits(doon2),
        self.class.pad_cutter(cutter2),
        self.class.pad_cutter(cutter3),
        (folio || '').downcase.strip,
        self.class.pad_all_digits(rest)
      ].compact.reject(&:empty?).join(' ').strip
    end
  end
end
