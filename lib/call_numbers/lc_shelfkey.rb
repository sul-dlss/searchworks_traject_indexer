# frozen_string_literal: true

module CallNumbers
  class LcShelfkey < ShelfkeyBase
    CUTTER_ROUNDING = 6

    delegate :scheme, :klass, :klass_number, :klass_decimal, :doon1, :doon2, :doon3,
             :cutter1, :cutter2, :cutter3, :folio, :rest, :serial, to: :call_number

    def to_shelfkey
      [
        scheme,
        (pad(klass.downcase, by: 3, character: ' ') if klass),
        [pad(klass_number, by: 4, direction: :left), pad(klass_decimal || '.')].join,
        pad_all_digits(doon1),
        pad_cutter(cutter1),
        pad_all_digits(doon2),
        pad_cutter(cutter2),
        pad_all_digits(doon3),
        pad_cutter(cutter3),
        (folio || '').downcase.strip,
        rest,
        volume_info_with_serial_behavior
      ].compact.reject(&:empty?).join(' ').strip
    end
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
