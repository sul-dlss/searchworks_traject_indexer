# frozen_string_literal: true

require 'traject_plus'

module Traject
  # A Traject reader for processing JSON exports from FOLIO via stdin.
  # @example An export can be produced by doing:
  #  require 'traject/readers/folio_postgres_reader'
  #  record = Traject::FolioPostgresReader.find_by_catkey('a14238203', 'postgres.url' => ENV['DATABASE_URL']
  #  File.write("a14238203.json", JSON.pretty_generate(record.as_json))
  class FolioJsonReader < TrajectPlus::JsonReader
    def each(&)
      return to_enum(:each) unless block_given?

      super do |record|
        yield FolioRecord.new(record, nil)
      end
    end
  end
end
