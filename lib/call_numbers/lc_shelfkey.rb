# frozen_string_literal: true

module CallNumbers
  class LcShelfkey < Shelfkey
    CUTTER_ROUNDING = 6

    attr_reader :call_number, :serial,
                :klass, :klass_number, :klass_decimal, :doon1, :doon2, :doon3, :cutter1, :cutter2, :cutter3, :folio, :rest, :volume_info

    def initialize(call_number, volume_info = nil, serial: false)
      super(call_number)
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
      @volume_info = volume_info
      @serial = serial
    end

    def to_shelfkey(omit_volume_info: false)
      [
        'lc',
        (pad(klass.downcase, by: 3, character: ' ') if klass),
        [pad(klass_number, by: 4, direction: :left), pad(klass_decimal || '.')].join,
        pad_all_digits(doon1),
        pad_cutter(cutter1),
        pad_all_digits(doon2),
        pad_cutter(cutter2),
        pad_all_digits(doon3),
        pad_cutter(cutter3),
        (folio || '').downcase.strip,
        self.class.pad_all_digits(rest&.downcase),
        (volume_info_with_serial_behavior unless omit_volume_info)
      ].compact.reject(&:empty?).join(' ').strip
    end

    private

    def pad_cutter(cutter)
      return unless cutter

      cutter = cutter.downcase.sub(/^\./, '') # downcase and remove opening period
      # Round numbers to 6
      cutter.sub!(/(\d+)/, round_cutter_number(cutter[/\d+/])) if cutter[/\d+/].length > CUTTER_ROUNDING
      cutter.sub!(/(\d+)/, ".#{pad(cutter[/\d+/])}") # Pad numbers
      cutter.sub!(/([a-z]+)/, pad(cutter[/[a-z]+/], by: 2)) # Pad letters
      cutter
    end

    # We are currently rounding the cutter numbers for parity with the sw-solrmarc
    # shelfkey logic.  We may want to revisit this in the future as we could
    # use larger padding here to account for larger cutters instead.
    def round_cutter_number(number, by: CUTTER_ROUNDING)
      "0.#{number}".to_f.round(by).to_s.sub(/^0\./, '')
    end
  end
end
