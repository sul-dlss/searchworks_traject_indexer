# frozen_string_literal: true

module CallNumbers
  class OtherShelfkey < ShelfkeyBase
    # shortcutting a shelfkey class as we just need the normalization/reverse methods
    def to_shelfkey
      [shelfkey_scheme, CallNumbers::ShelfkeyBase.pad_all_digits(call_number.call_number)].join(' ')
    end

    def to_reverse_shelfkey
      CallNumbers::ShelfkeyBase.reverse(to_shelfkey).ljust(50, '~')
    end

    private

    # this transfomation only applies when generating shelfkeys
    def shelfkey_scheme
      return 'sudoc' if call_number.scheme == 'SUDOC'

      'other'
    end
  end
end
