# frozen_string_literal: true

module CallNumbers
  require 'forwardable'
  class CallNumberBase
    extend Forwardable
    delegate %i[to_shelfkey to_reverse_shelfkey] => :shelfkey

    def scheme
      raise NotImplementedError
    end

    def lopped
      raise NotImplementedError
    end

    def to_lopped_shelfkey
      self.class.new(lopped, serial:).to_shelfkey
    end

    def to_lopped_reverse_shelfkey
      if lopped == call_number
        self.class.new(lopped, serial:).to_reverse_shelfkey
      else
        # Explicitly passing in the ellipsis (as it needs to be reversed)
        # and dropping the serial since it has already been lopped
        self.class.new("#{lopped} ...").to_reverse_shelfkey
      end
    end

    def to_volume_sort
      to_shelfkey
    end

    def base_call_number
      call_number
    end

    private

    def shelfkey
      shelfkey_class.new(self)
    end

    def shelfkey_class
      raise NotImplementedError
    end
  end
end
