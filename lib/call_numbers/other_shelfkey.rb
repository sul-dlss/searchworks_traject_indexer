# frozen_string_literal: true

module CallNumbers
  class OtherShelfkey < Shelfkey
    attr_reader :call_number, :volume_info, :serial, :scheme

    def initialize(call_number, volume_info = nil, serial: false, scheme: '')
      super(call_number)
      @call_number = call_number
      @volume_info = volume_info
      @serial = serial
      @scheme = scheme
    end

    # shortcutting a shelfkey class as we just need the normalization/reverse methods
    def to_shelfkey(omit_volume_info: false)
      [
        shelfkey_scheme,
        CallNumbers::Shelfkey.pad_all_digits(call_number),
        (volume_info_with_serial_behavior unless omit_volume_info)
      ].compact.join(' ')
    end

    private

    # this transfomation only applies when generating shelfkeys
    def shelfkey_scheme
      return 'sudoc' if scheme == 'SUDOC'

      'other'
    end
  end
end
