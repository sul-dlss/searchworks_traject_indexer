# frozen_string_literal: true

module CallNumbers
  class DeweyShelfkey < Shelfkey
    attr_reader :scheme, :klass_number, :klass_decimal, :doon1, :doon2, :cutter1, :cutter2, :cutter3, :folio, :rest, :serial

    def initialize(call_number, volume_info = nil, serial: false)
      super(call_number)
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

    def to_shelfkey(omit_volume_info: false)
      [
        'dewey',
        self.class.pad(klass_number, by: 3, direction: :left, character: '0'),
        self.class.pad((klass_decimal || '.'), by: 8),
        self.class.pad_all_digits(doon1),
        normalize_dewey_cutter(cutter1),
        self.class.pad_all_digits(doon2),
        normalize_dewey_cutter(cutter2),
        normalize_dewey_cutter(cutter3),
        (folio || '').downcase.strip,
        self.class.pad_all_digits(rest&.downcase),
        (volume_info_with_serial_behavior unless omit_volume_info)
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
