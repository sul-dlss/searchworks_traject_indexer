# frozen_string_literal: true

module CallNumbers
  class LC < CallNumberBase
    attr_reader :call_number, :serial,
                :klass, :klass_number, :klass_decimal, :doon1, :doon2, :doon3, :cutter1, :cutter2, :cutter3, :folio, :rest, :potential_stuff_to_lop,
                :volume_info

    def initialize(call_number, volume_info = '', serial: false)
      match_data = /
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
      /x.match(call_number)

      @call_number = call_number
      match_data ||= {}
      @klass = match_data[:klass] || ''
      @klass_number = match_data[:klass_number]
      @klass_decimal = match_data[:klass_decimal]
      @doon1 = match_data[:doon1]
      @cutter1 = match_data[:cutter1]
      @doon2 = match_data[:doon2]
      @cutter2 = match_data[:cutter2]
      @doon3 = match_data[:doon3]
      @cutter3 = match_data[:cutter3]
      @folio = match_data[:folio]
      @rest = match_data[:rest]
      @potential_stuff_to_lop = match_data[:potential_stuff_to_lop]
      @volume_info = volume_info
      @serial = serial
    end

    def scheme
      'lc'
    end

    def lopped
      @lopped ||= begin
        value = case potential_stuff_to_lop
                when VOL_PATTERN
                  call_number.slice(0...call_number.index(potential_stuff_to_lop[VOL_PATTERN])).strip
                when VOL_PATTERN_LOOSER
                  call_number.slice(0...call_number.index(potential_stuff_to_lop[VOL_PATTERN_LOOSER])).strip
                when VOL_PATTERN_LETTERS
                  call_number.slice(0...call_number.index(potential_stuff_to_lop[VOL_PATTERN_LETTERS])).strip
                when ADDL_VOL_PATTERN
                  call_number.slice(0...call_number.index(potential_stuff_to_lop[ADDL_VOL_PATTERN])).strip
                else
                  call_number
                end

        value = value[0...(value.index(LOOSE_MONTHS_REGEX) || value.length)] # remove loose months

        if serial
          self.class.lop_years(value)
        else
          value.strip
        end
      end
    end

    private

    def shelfkey_class
      CallNumbers::Shelfkey
    end
  end
end
