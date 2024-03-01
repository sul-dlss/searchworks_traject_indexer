# frozen_string_literal: true

module CallNumbers
  class LcShelfkey < ShelfkeyBase
    delegate :base_call_number, to: :call_number

    def to_shelfkey
      [
        'lc',
        (pad(parsed[:klass].downcase, by: 3, character: ' ') if parsed[:klass]),
        [pad(parsed[:klass_number], by: 4, direction: :left), pad(parsed[:klass_decimal] || '.')].join,
        pad_all_digits(parsed[:doon1]),
        pad_cutter(parsed[:cutter1]),
        pad_all_digits(parsed[:doon2]),
        pad_cutter(parsed[:cutter2]),
        pad_all_digits(parsed[:doon3]),
        pad_cutter(parsed[:cutter3]),
        (parsed[:folio] || '').downcase.strip,
        self.class.pad_all_digits(parsed[:rest]),
        volume_info_with_serial_behavior
      ].filter_map(&:presence).join(' ').strip
    end

    private

    def parsed
      @parsed ||= /
        (?<klass>[A-Z]{0,3})\s*
        (?<klass_number>\d+)?(?<klass_decimal>\.?\d+)?\s*
        (?<doon1>(\d{1,4})(?:ST|ND|RD|TH|D)?\s+)?\s*
        (?<cutter1>\.?[a-zA-Z]+\d+([a-zA-Z]+(?![0-9]))?)?\s*
        (?<potential_stuff_to_lop>(?<doon2>(\d{1,4})(?:ST|ND|RD|TH|D)?\s+)?\s*
        (?<cutter2>\.?[a-zA-Z]+\d+([a-zA-Z]+(?![0-9]))?)?\s*
        (?<doon3>(\d{1,4})(?:ST|ND|RD|TH|D)?\s+)?\s*
        (?<cutter3>\.?[a-zA-Z]+\d+([a-zA-Z]+(?![0-9]))?)?\s*
        (?<folio>(?<=\s)?F{1,2}(?=(\s|$)))?
        (?<rest>.*))
      /x.match(base_call_number)

      @parsed ||= {}
    end
  end
end
