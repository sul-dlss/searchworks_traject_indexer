# frozen_string_literal: true

module CallNumbers
  require 'forwardable'
  class CallNumberBase
    extend Forwardable

    def scheme
      raise NotImplementedError
    end

    def lopped
      raise NotImplementedError
    end

    def to_lopped_shelfkey
      self.class.new(lopped, serial:).shelfkey
    end

    def shelfkey
      @shelfkey ||= shelfkey_class.new(self)
    end

    def to_volume_sort
      shelfkey.forward
    end

    def base_call_number
      call_number
    end

    private

    def shelfkey_class
      raise NotImplementedError
    end
  end
end
