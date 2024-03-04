# frozen_string_literal: true

module CallNumbers
  class Dewey < CallNumberBase
    attr_reader :call_number, :serial, :volume_info

    def initialize(call_number, volume_info = '', serial: false)
      @call_number = call_number
      @serial = serial
      @volume_info = volume_info
    end

    def scheme
      'dewey'
    end

    def lopped
      call_number
    end

    private

    def shelfkey_class
      CallNumbers::DeweyShelfkey
    end
  end
end
