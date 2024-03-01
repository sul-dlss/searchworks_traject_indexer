# frozen_string_literal: true

module CallNumbers
  class Other < CallNumberBase
    attr_reader :call_number, :serial, :scheme, :volume_info

    def initialize(call_number, volume_info = '', serial: false, scheme: '')
      @call_number = call_number
      @volume_info = volume_info
      @serial = serial
      @scheme = scheme
    end

    def to_lopped_shelfkey
      self.class.new(lopped, serial:, scheme:).shelfkey
    end

    def lopped
      call_number
    end

    private

    def shelfkey_class
      CallNumbers::OtherShelfkey
    end
  end
end
