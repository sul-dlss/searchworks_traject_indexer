# frozen_string_literal: true

require 'call_numbers/shelfkey_base'

module CallNumbers
  class DeweyShelfkey < ShelfkeyBase
    def forward
      [
        'dewey',
        klass_number_and_decimal,
        self.class.pad_all_digits(parsed[:doon1]),
        normalize_dewey_cutter(parsed[:cutter1]),
        self.class.pad_all_digits(parsed[:doon2]),
        normalize_dewey_cutter(parsed[:cutter2]),
        normalize_dewey_cutter(parsed[:cutter3]),
        (parsed[:folio] || '').downcase.strip,
        self.class.pad_all_digits(parsed[:rest]),
        volume_info_with_serial_behavior
      ].filter_map(&:presence).join(' ').strip
    end

    private

    def parsed
      @parsed ||= %r{
        (?<klass_number>\d{1,3})(?<klass_decimal>\.?\d+)?\s*
        (?<doon1>(\d{1,4})(?:ST|ND|RD|TH|D)?\s+)?\s*
        (?<cutter1>[\./]?[a-zA-Z]+\d+([a-zA-Z]*(?![0-9])))?\s*
        (?<potential_stuff_to_lop>(?<doon2>(\d{1,4})(?:ST|ND|RD|TH|D)?\s+)?\s*
        (?<cutter2>[\./]?[a-zA-Z]+\d+([a-zA-Z]*(?![0-9])))?\s*
        (?<doon3>(\d{1,4})(?:ST|ND|RD|TH|D)?\s+)?\s*
        (?<cutter3>[\./]?[a-zA-Z]+\d+([a-zA-Z]*(?![0-9])))?\s*
        (?<folio>(?<=\s)?F{1,2}(?=(\s|$)))?
        (?<rest>.*))
      }x.match(base_call_number)
      @parsed ||= {}
    end

    def klass_number_and_decimal
      [
        self.class.pad(parsed[:klass_number], by: 3, direction: :left, character: '0'),
        self.class.pad((parsed[:klass_decimal] || '.'), by: 8)
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
