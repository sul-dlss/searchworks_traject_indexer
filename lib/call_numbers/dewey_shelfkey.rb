# frozen_string_literal: true

require 'call_numbers/shelfkey_base'

module CallNumbers
  class DeweyShelfkey < ShelfkeyBase
    delegate :scheme, :klass_number, :klass_decimal, :doon1, :doon2,
             :cutter1, :cutter2, :cutter3, :folio, :rest, :serial, to: :call_number

    def to_shelfkey
      [
        scheme,
        self.class.pad(klass_number, by: 3, direction: :left, character: '0'),
        self.class.pad((klass_decimal || '.'), by: 8),
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

    def normalize_dewey_cutter(cutter)
      return unless cutter

      cutter = cutter.delete('.')
      cutter = cutter.delete('/')
      cutter.downcase
    end
  end
end
