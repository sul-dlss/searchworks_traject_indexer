# frozen_string_literal: true

module Folio
  # The library data model
  class Library
    def initialize(code:, name:)
      @code = code
      @name = name
    end

    attr_reader :code, :name

    def self.from_dyn(data)
      new(
        code: data.fetch('code'),
        name: data.fetch('name')
      )
    end
  end
end
