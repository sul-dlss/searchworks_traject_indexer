require 'call_numbers/shelfkey_base'
require 'call_numbers/call_number_base'

module CallNumbers
  class Other < CallNumberBase

    attr_reader :call_number, :longest_common_prefix, :serial

    def initialize(call_number, longest_common_prefix: '', serial: false, scheme: nil)
      @call_number = call_number
      @longest_common_prefix = longest_common_prefix
      @serial = serial
      @scheme = scheme
    end

    def scheme
      return 'sudoc' if @scheme == 'SUDOC'
      'other'
    end

    def lopped
      return call_number if longest_common_prefix.empty? || longest_common_prefix =~ /^(mcd|mdvd|zdvd|mfilm|mfiche)$/i

      lopped_call_number = longest_common_prefix.sub(Regexp.union(/(20|19|18)\d{0,2}$/, /(20|19|18)\d{2}[ -:]$/), '')

      lopped_vol_pattern = /[ \.\(\:\/](#{VOL_PARTS})/i
      lopped_addl_vol_pattern = /[ \.\(\:\/](#{ADDL_VOL_PARTS.join('|')}).*/i

      lopped_call_number = lopped_call_number.slice(0...(lopped_call_number.index(lopped_vol_pattern) || lopped_call_number.index(lopped_addl_vol_pattern) || lopped_call_number.length))
      lopped_call_number = lopped_call_number.sub(/[\-:\(\\]$/, '').strip
      return call_number if lopped_call_number =~ /^(mcd|mdvd|zdvd|mfilm|mfiche)$/i
      return call_number if lopped_call_number.length <= 4

      lopped_call_number
    end

    # shortcutting a shelfkey class as we just need the normalization/reverse methods
    def to_shelfkey
      [scheme, CallNumbers::ShelfkeyBase.pad_all_digits(call_number)].join(' ')
    end

    def to_reverse_shelfkey
      CallNumbers::ShelfkeyBase.reverse(to_shelfkey)
    end
  end
end
