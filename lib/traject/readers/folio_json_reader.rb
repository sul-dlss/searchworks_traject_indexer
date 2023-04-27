# frozen_string_literal: true

require 'traject_plus'
require_relative '../../folio_client'
require_relative '../../folio_record'

module Traject
  # A Traject reader for processing MARC JSON from FOLIO via stdin.
  class FolioJsonReader < TrajectPlus::JsonReader
    def each(&)
      return to_enum(:each) unless block_given?

      super do |record|
        yield FolioRecord.new(record, nil)
      end
    end
  end
end
