# frozen_string_literal: true

require 'time'
require_relative '../../folio_client'
require_relative '../../folio_record'

module Traject
  class FolioReader
    attr_reader :settings, :last_response_date

    def initialize(_input_stream, settings)
      @settings = Traject::Indexer::Settings.new settings
    end

    def each
      return to_enum(:each) unless block_given?

      response = client.get('/source-storage/stream/source-records',
                            params: { limit: settings.fetch('source-records-limit', 2_147_483_647).to_i,
                                      updatedAfter: settings.fetch('folio.updated_after', Time.at(0).utc.iso8601) })
      buffer = ''
      @last_response_date = Time.httpdate(response.headers['Date'])

      while data = response.readpartial
        buffer += data
        newbuffer = ''

        buffer.each_line do |line|
          if line.end_with?("\n")
            record = JSON.parse(line)
            yield FolioRecord.new({
                                    'source_record' => [
                                      record.dig('parsedRecord', 'content')
                                    ],
                                    'instance' => {
                                      'id' => record.dig('externalIdsHolder', 'instanceId')
                                    }
                                  }, client)
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
