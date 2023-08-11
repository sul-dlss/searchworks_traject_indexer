# frozen_string_literal: true

module Folio
  # A cache of library data
  class LibraryStore
    def initialize(data_from_cache)
      @data = data_from_cache.map { |library| Library.from_dyn(library) }
    end

    attr_reader :data

    def find_by(code:)
      data.find { |candidate| candidate.code == code }
    end
  end
end
