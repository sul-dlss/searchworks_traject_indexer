# frozen_string_literal: true

module CallNumbers
  class LC < CallNumberBase
    attr_reader :call_number, :serial, :volume_info

    def initialize(call_number, volume_info = '', serial: false)
      @call_number = call_number
      @volume_info = volume_info
      @serial = serial
    end

    def scheme
      'lc'
    end

    def lopped
      call_number
    end

    private

    def shelfkey_class
      CallNumbers::LcShelfkey
    end
  end
end
