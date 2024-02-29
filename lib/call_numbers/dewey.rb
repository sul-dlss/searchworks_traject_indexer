# frozen_string_literal: true

module CallNumbers
  class Dewey < CallNumberBase
    attr_reader :call_number, :serial,
                :klass_number, :klass_decimal, :doon1, :doon2, :doon3, :cutter1, :cutter2, :cutter3, :folio, :rest, :volume_info

    def initialize(call_number, volume_info: nil, serial: false)
      match_data = %r{
        (?<klass_number>\d{1,3})(?<klass_decimal>\.?\d+)?\s*
        (?<doon1>(\d{1,4})(?:ST|ND|RD|TH|D)?\s+)?\s*
        (?<cutter1>[\./]?[a-zA-Z]+\d+([a-zA-Z]*(?![0-9])))?\s*
        (?<potential_stuff_to_lop>(?<doon2>(\d{1,4})(?:ST|ND|RD|TH|D)?\s+)?\s*
        (?<cutter2>[\./]?[a-zA-Z]+\d+([a-zA-Z]*(?![0-9])))?\s*
        (?<doon3>(\d{1,4})(?:ST|ND|RD|TH|D)?\s+)?\s*
        (?<cutter3>[\./]?[a-zA-Z]+\d+([a-zA-Z]*(?![0-9])))?\s*
        (?<folio>(?<=\s)?F{1,2}(?=(\s|$)))?
        (?<rest>.*))
      }x.match(call_number)

      @call_number = call_number
      match_data ||= {}
      @klass_number = match_data[:klass_number]
      @klass_decimal = match_data[:klass_decimal]
      @doon1 = match_data[:doon1]
      @cutter1 = match_data[:cutter1]
      @doon2 = match_data[:doon2]
      @doon3 = match_data[:doon3]
      @cutter2 = match_data[:cutter2]
      @cutter3 = match_data[:cutter3]
      @folio = match_data[:folio]
      @rest = match_data[:rest]
      @volume_info = volume_info
      @serial = serial
    end

    def scheme
      'dewey'
    end

    private

    def shelfkey_class
      CallNumbers::DeweyShelfkey
    end
  end
end
