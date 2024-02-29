# frozen_string_literal: true

module CallNumbers
  class Other < CallNumberBase
    VOL_PARTS = '(bd|ed|jahrg|new ser|no|pts?|series|[^a-z]t|v|vols?|vyp)'
    ADDL_VOL_PARTS = [
      'box', 'carton', 'disc', 'flat box', 'grade', 'half box', 'half carton',
      'index', 'large folder', 'large map folder', 'map folder', 'reel', 'os box',
      'os folder', 'small folder', 'small map folder', 'suppl', 'tube', 'series'
    ]

    attr_reader :call_number, :longest_common_prefix, :serial, :scheme

    def initialize(call_number, longest_common_prefix: '', serial: false, scheme: '')
      @call_number = call_number
      @longest_common_prefix = longest_common_prefix
      @serial = serial
      @scheme = scheme
    end

    def to_lopped_shelfkey
      self.class.new(lopped, serial:, scheme:).to_shelfkey
    end

    def to_lopped_reverse_shelfkey
      self.class.new(lopped, serial:, scheme:).to_reverse_shelfkey
    end

    def lopped
      return call_number if longest_common_prefix.empty? || longest_common_prefix =~ /^(mcd|mdvd|zdvd|mfilm|mfiche)$/i

      lopped_call_number = longest_common_prefix.sub(Regexp.union(/ (20|19|18)\d{0,2}$/, / (20|19|18)\d{2}[ -:]$/), '')

      lopped_vol_pattern = %r{[ .(:/](#{VOL_PARTS})}i
      lopped_addl_vol_pattern = %r{[ .(:/](#{ADDL_VOL_PARTS.join('|')}).*}i

      lopped_call_number = lopped_call_number.slice(0...(lopped_call_number.index(lopped_vol_pattern) || lopped_call_number.index(lopped_addl_vol_pattern) || lopped_call_number.length))
      lopped_call_number = lopped_call_number.sub(/[-:(\\]$/, '').strip
      return call_number if lopped_call_number =~ /^(mcd|mdvd|zdvd|mfilm|mfiche)$/i
      return call_number if lopped_call_number.length <= 4

      lopped_call_number
    end
  end
end
