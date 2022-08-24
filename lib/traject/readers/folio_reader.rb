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

      response = client.get('/source-storage/source-records', params: { limit: settings.fetch('source-records-limit', 2147483647).to_i, updatedAfter: settings.fetch('folio.updated_after', Time.at(0).utc.iso8601) })
      @last_response_date = Time.httpdate(response.headers['Date'])
      parsed_response = JSON.parse(response.body)
      instance_ids = parsed_response['sourceRecords'].map { |source_record| source_record.dig('externalIdsHolder', 'instanceId') }.compact.uniq

      # fetch items and holdings for all the source records that aren't suppressed
      body = {
        instanceIds: instance_ids,
        skipSuppressedFromDiscoveryRecords: true
      }
      items_and_holdings = client.get_jsonl('/inventory-hierarchy/items-and-holdings', method: :post, body: body.to_json)

      # join items/holdings with source record into a single struct
      record_structs = parsed_response['sourceRecords'].map do |source_record|
        instance_id = source_record.dig('externalIdsHolder', 'instanceId')

        {
          'source_record' => [source_record.dig('parsedRecord', 'content')],
          'instance' => { 'id' => instance_id },
          'items' => items_and_holdings.select { |rec| rec['instanceId'] == instance_id },
          'holdings' => items_and_holdings.select { |rec| rec['instanceId'] == instance_id }
        }
      end

      # yield one FolioRecord for each struct
      record_structs.each do |record_struct|
        yield FolioRecord.new(record_struct, client)
      end
    end

    private

    def client
      @client ||= settings['folio.client'] || FolioClient.new
    end
  end
end
