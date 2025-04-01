# frozen_string_literal: true

module CallNumbers
  class OtherShelfkey < ShelfkeyBase
    # shortcutting a shelfkey class as we just need the normalization/reverse methods
    def forward
      [
        shelfkey_scheme,
        CallNumbers::ShelfkeyBase.pad_all_digits(base_call_number),
        volume_info_with_serial_behavior
      ].filter_map(&:presence).join(' ')
    end

    private

    # this transfomation only applies when generating shelfkeys
    def shelfkey_scheme
      'other'
    end
  end
end
