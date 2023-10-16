# frozen_string_literal: true

module Traject
  # A Traject reader for processing JSON exports from FOLIO via stdin.
  # @example An export can be produced by doing:
  #  bin/console
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
