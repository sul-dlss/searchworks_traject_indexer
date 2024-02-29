# frozen_string_literal: true

module CallNumbers
  class Other < CallNumberBase
    attr_reader :call_number, :volume_info, :serial, :scheme

    def initialize(call_number, volume_info = nil, serial: false, scheme: '')
      @call_number = call_number
      @volume_info = volume_info
      @serial = serial
      @scheme = scheme
    end
  end
end
