# frozen_string_literal: true

module CallNumbers
  require 'forwardable'
  class CallNumberBase
    extend Forwardable
    delegate %i[to_shelfkey to_reverse_shelfkey] => :shelfkey

    def scheme
      raise NotImplementedError
    end

    private

    def shelfkey
      shelfkey_class.new(self)
    end

    def shelfkey_class
      CallNumbers::OtherShelfkey
    end
  end
end
