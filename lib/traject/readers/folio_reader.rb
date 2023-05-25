# frozen_string_literal: true

require 'time'

module Traject
  class FolioReader
    attr_reader :settings, :last_response_date

    def initialize(_input_stream, settings)
      @settings = Traject::Indexer::Settings.new settings
    end

    def each
      return to_enum(:each) unless block_given?

      response = client.stream_source_records(updated_after: settings.fetch('folio.updated_after', Time.at(0).utc.iso8601))
      buffer = ''
      @last_response_date = Time.httpdate(response.headers['Date'])

      while data = response.readpartial
        buffer += data
        newbuffer = ''

        buffer.each_line do |line|
          if line.end_with?("\n")
            record = JSON.parse(line)
            yield FolioRecord.new_from_source_record(record, client)
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
