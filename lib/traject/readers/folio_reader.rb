require_relative '../../folio_client.rb'

module Traject
  class FolioReader
    attr_reader :settings

    def initialize(input_stream, settings)
      @settings = Traject::Indexer::Settings.new settings
    end

    def each(&block)
      return to_enum(:each) unless block_given?

      response = client.get('/source-storage/stream/source-records?limit=2147483647')
      buffer = ""

      while data = response.readpartial
        buffer += data
        newbuffer = ''

        buffer.each_line do |line|
          if line.end_with?("\n")
            yield FolioRecord.new(JSON.parse(line))
          else
            newbuffer += line
          end
        end

        buffer = newbuffer
      end
    end

    class FolioRecord
      attr_reader :record

      def initialize(record)
        @record = record
      end

      def fields(...)
        marc_record.fields(...)
      end

      def marc_record
        @marc_record ||= MARC::Record.new_from_hash(record.dig('parsedRecord', 'content'))
      end
    end

    private

    def client
      @client ||= FolioClient.new
    end
  end
end
