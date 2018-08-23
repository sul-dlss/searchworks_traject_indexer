require 'call_numbers/shelfkey_base'

module CallNumbers
  class DeweyShelfkey < ShelfkeyBase
    def to_shelfkey
      [
        call_number.scheme,
        klass_number_and_decimal,
        self.class.pad_all_digits(doon1),
        normalize_dewey_cutter(cutter1),
        self.class.pad_all_digits(doon2),
        normalize_dewey_cutter(cutter2),
        normalize_dewey_cutter(cutter3),
        (folio || '').downcase.strip,
        rest_with_serial_behavior
      ].compact.reject(&:empty?).join(' ').strip
    end

    private

    # Unit tests inidcate that serial deweys don't get reversed years justified with tildes
    def rest_with_serial_behavior
      return unless rest
      self.class.pad_all_digits(rest)
      # return self.class.pad_all_digits(rest) unless serial
      # self.class.reverse(self.class.pad_all_digits(rest)).strip.ljust(50, '~')
    end

    def klass_number_and_decimal
      [
        self.class.pad(klass_number, by: 3, direction: :left, character: '0'),
        self.class.pad((klass_decimal || '.'), by: 8)
      ].join('')
    end

    def normalize_dewey_cutter(cutter)
      return unless cutter
      cutter = cutter.delete('.')
      cutter = cutter.delete('/')
      cutter.downcase
    end
  end
end
