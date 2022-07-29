require 'active_support/core_ext/module/delegation'
require_relative '../../folio_client.rb'

module Traject
  class FolioReader
    attr_reader :settings

    def initialize(input_stream, settings)
      @settings = Traject::Indexer::Settings.new settings
    end

    def each(&block)
      return to_enum(:each) unless block_given?

      response = client.get('/source-storage/stream/source-records', params: { limit: settings.fetch('source-records-limit', 2147483647).to_i })
      buffer = ""

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

    class FolioRecord
      attr_reader :record, :client
      delegate :fields, :each, :[], to: :marc_record

      def self.fetch(id, client: FolioClient.new)
        FolioRecord.new(client.get_json("/source-storage/source-records", params: { instanceHrid: "a#{id}" }).dig('sourceRecords', 0), client)
      end

      def initialize(record, client)
        @record = record
        @client = client
      end

      def marc_record
        @marc_record ||= MARC::Record.new_from_hash(record.dig('parsedRecord', 'content'))
      end

      def holdings
        @holdings ||= client.get_json("/holdings-storage/holdings", params: { limit: 2147483647, query: "instanceId==\"#{instance_id}\"" }).dig('holdingsRecords')
      end

      def instance_id
        record.dig('externalIdsHolder', 'instanceId')
      end

      def call_number_type(call_number_uuid)
        client.call_number_types[call_number_uuid] || call_number_uuid
      end

      def items
        return [] unless holdings.any?

        @items ||= begin
          query = holdings.map { |h| "holdingsRecordId==\"#{h['id']}\"" }.join(' OR ')
          client.get_json("/item-storage-dereferenced/items", params: { limit: 2147483647, query: query }).dig('dereferencedItems')
        end
      end
    end

    private

    def client
      @client ||= FolioClient.new
    end
  end
end
