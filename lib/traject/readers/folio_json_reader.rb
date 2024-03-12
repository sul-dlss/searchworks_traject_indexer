# frozen_string_literal: true

module Traject
  # A Traject reader for processing JSON exports from FOLIO via stdin.
  # @example An export can be produced by doing:
  #  bin/console
  #  record = Traject::FolioPostgresReader.find_by_catkey('a14238203', 'postgres.url' => ENV['DATABASE_URL']
  #  File.write("a14238203.json", record.to_json)
  class FolioJsonReader < Traject::NDJReader
    def each(&)
      return enum_for(:each) unless block_given?

      @input_stream.each_with_index do |json, i|
        yield FolioRecord.new(JSON.parse(Utils.encoding_cleanup(json)), nil)
      rescue StandardError => e
        logger.error("Problem with JSON record on line #{i}: #{e.message}")
      end
    end
  end
end
