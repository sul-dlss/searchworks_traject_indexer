require 'active_support/core_ext/module/delegation'

class FolioRecord
  attr_reader :record, :client
  delegate :fields, :each, :[], :leader, :tags, :select, :find_all, :to_hash, to: :marc_record

  def initialize(record, client)
    @record = record
    @client = client
  end

  def marc_record
    @marc_record ||= MARC::Record.new_from_hash(record.dig('parsedRecord', 'content'))
  end

  def instance_id
    record.dig('externalIdsHolder', 'instanceId')
  end

  def items
    items_and_holdings&.dig('items') || []
  end

  def items_and_holdings
    @items_and_holdings ||= begin
      body = {
        instanceIds: [instance_id],
        skipSuppressedFromDiscoveryRecords: false
      }
      client.get_json("/inventory-hierarchy/items-and-holdings", method: :post, body: body.to_json)
    end
  end
end
