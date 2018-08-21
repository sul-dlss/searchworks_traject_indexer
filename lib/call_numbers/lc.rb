require 'call_numbers/shelfkey'
require 'call_numbers/call_number_base'

module CallNumbers
  class LC < CallNumberBase
    attr_reader :call_number, :serial,
                :klass, :klass_number, :klass_decimal, :doon1, :doon2, :cutter1, :cutter2, :cutter3, :folio, :rest

    def initialize(call_number, serial: false)
      match_data = /
        (?<klass>[A-Z]{0,3})\s*
        (?<klass_number>\d+)(?<klass_decimal>\.?\d+)?\s*
        (?<doon1>(\d{1,4})(?:ST|ND|RD|TH|D)?\s+)?\s*
        (?<cutter1>\.?[a-zA-Z]+\d+[a-zA-Z]?)?\s*
        (?<doon2>(\d{1,4})(?:ST|ND|RD|TH|D)?\s+)?\s*
        (?<cutter2>\.?[a-zA-Z]+\d+[a-zA-Z]?)?\s*
        (?<cutter3>\.?[a-zA-Z]+\d+[a-zA-Z]?)?
        (?<folio>\s?[F]\s?)?
        (?<rest>.*)
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
      @cutter3 = match_data[:cutter3]
      @folio = match_data[:folio]
      @rest = match_data[:rest]
      @serial = serial
    end

    def scheme
      'lc'
    end

    def lopped
      value = case call_number
              when VOL_PATTERN
                call_number.slice(0...call_number.index(VOL_PATTERN)).strip
              when VOL_PATTERN_LOOSER
                call_number.slice(0...call_number.index(VOL_PATTERN_LOOSER)).strip
              when VOL_PATTERN_LETTERS
                call_number.slice(0...call_number.index(VOL_PATTERN_LETTERS)).strip
              when ADDL_VOL_PATTERN
                call_number.slice(0...call_number.index(ADDL_VOL_PATTERN)).strip
              else
                call_number
              end

      value = value[0...(value.index(LOOSE_MONTHS_REGEX) || value.length)] # remove loose months

      return self.class.lop_years(value) if serial
      value.strip
    end

    private

    def shelfkey_class
      return CallNumbers::SerialShelfkey if serial
      CallNumbers::Shelfkey
    end
  end
end
