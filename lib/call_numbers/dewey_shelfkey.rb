# frozen_string_literal: true

require 'call_numbers/shelfkey_base'

module CallNumbers
  class DeweyShelfkey < ShelfkeyBase
    delegate :scheme, :klass, :klass_number, :klass_decimal, :doon1, :doon2,
             :cutter1, :cutter2, :cutter3, :folio, :rest, :serial, to: :call_number

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
        self.class.pad_all_digits(rest),
        volume_info_with_serial_behavior
      ].filter_map(&:presence).join(' ').strip
    end

    private

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
