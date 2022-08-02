require 'active_support/core_ext/module/delegation'

class FolioRecord
  attr_reader :record, :client
  delegate :fields, :each, :[], :leader, :tags, :select, :find_all, to: :marc_record

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
