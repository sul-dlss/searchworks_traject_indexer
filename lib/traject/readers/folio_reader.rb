require 'time'
require_relative '../../folio_client'
require_relative '../../folio_record'

module Traject
  class FolioReader
    attr_reader :settings, :last_response_date

    def initialize(input_stream, settings)
      @settings = Traject::Indexer::Settings.new settings
    end

    def each(&block)
      return to_enum(:each) unless block_given?

      response = client.get('/source-storage/stream/source-records', params: { limit: settings.fetch('source-records-limit', 2147483647).to_i, updatedAfter: settings['folio.updated_after'] })
      buffer = ""
      @last_response_date = Time.httpdate(response.headers['Date'])

      while data = response.readpartial
        buffer += data
        newbuffer = ''

        buffer.each_line do |line|
          if line.end_with?("\n")
            yield FolioRecord.new(JSON.parse(line), client)
          else
            newbuffer += line
          end
        end

        buffer = newbuffer
      end
    end

    private

    def client
      @client ||= settings['folio.client'] || FolioClient.new
    end
  end
end
