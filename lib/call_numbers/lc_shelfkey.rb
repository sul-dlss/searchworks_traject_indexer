# frozen_string_literal: true

module CallNumbers
  class LcShelfkey < ShelfkeyBase
    delegate :scheme, :klass, :klass_number, :klass_decimal, :doon1, :doon2, :doon3,
             :cutter1, :cutter2, :cutter3, :folio, :rest, :serial, to: :call_number

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
        self.class.pad_all_digits(rest),
        volume_info_with_serial_behavior
      ].filter_map(&:presence).join(' ').strip
    end
  end
end
