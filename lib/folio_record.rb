require 'active_support/core_ext/module/delegation'
require_relative 'traject/common/constants'

class FolioRecord
  attr_reader :record, :client
  delegate :fields, :each, :[], :leader, :tags, :select, :find_all, :to_hash, to: :marc_record

  def self.new_from_source_record(record, client)
    FolioRecord.new({
      'source_record' => [
        record.dig('parsedRecord', 'content')
      ],
      'instance' => {
        'id' => record.dig('externalIdsHolder', 'instanceId')
      }
    }, client)
  end

  def initialize(record, client = nil)
    @record = record
    @client = client
  end

  def marc_record
    @marc_record ||= MARC::Record.new_from_hash(stripped_marc_json)
  end

  def instance_id
    record.dig('instance', 'id')
  end

  def hrid
    record.dig('instance', 'hrid')
  end

  def sirsi_holdings
    @sirsi_holdings ||= items.map do |item|
      holding = holdings.find { |holding| holding['id'] == item['holdingsRecordId'] }
      item_location_code = item.dig('location', 'permanentLocation', 'code')
      item_location_code ||= holding.dig('location', 'permanentLocation', 'code')
      library_code, home_location_code = self.class.folio_sirsi_locations_map[item_location_code]
      _current_library, current_location = self.class.folio_sirsi_locations_map[item.dig('location', 'location', 'code')]

      SirsiHolding.new(
        call_number: [item.dig('callNumber', 'callNumber'), item['volume']].compact.join(' '),
        current_location: (current_location unless current_location == home_location_code),
        home_location: home_location_code,
        library: library_code,
        scheme: call_number_type_map(item.dig('callNumber', 'typeName')),
        type: item['materialType'],
        barcode: item['barcode'],
        # TODO: not implementing public note (was 999 subfield o) currently
        tag: item
      )
    end
  end

  def call_number_type_map(name)
    case name
    when /dewey/i
      'DEWEY'
    when /congress/i, /LC/i
      'LC'
    when /superintendent/i
      'SUDOC'
    when /title/i, /shelving/i
      'ALPHANUM'
    else
      'OTHER'
    end
  end

  def self.folio_sirsi_locations_map
    @folio_sirsi_locations_map ||= begin
      CSV.parse(File.read(File.join(__dir__, 'translation_maps', 'locations.tsv')), col_sep: "\t").each_with_object({}) do |row, hash|
        library_code = row[1]
        library_code = { 'LANE' => 'LANE-MED' }.fetch(library_code, library_code)
        hash[row[2]] ||= [library_code, row[0]]
      end
    end
  end

  def items
    (record['items'] || items_and_holdings&.dig('items') || []).reject { |item| item['suppressFromDiscovery'] }
  end

  def holdings
    (record['holdings'] || items_and_holdings&.dig('holdings') || []).reject { |holding| holding['suppressFromDiscovery'] }
  end

  def as_json(include_items: false)
    json = record.except('source_record', 'items', 'holdings')

    if include_items
      json['items'] ||= items
      json['holdings'] ||= holdings
    end

    json
  end

  private

  def items_and_holdings
    @items_and_holdings ||= begin
      body = {
        instanceIds: [instance_id],
        skipSuppressedFromDiscoveryRecords: false
      }
      client.get_json('/inventory-hierarchy/items-and-holdings', method: :post, body: body.to_json)
    end
  end

  def stripped_marc_json
    record.dig('source_record', 0).tap do |record|
      record['fields'] = record['fields'].reject { |field| Constants::JUNK_TAGS.include?(field.keys.first) }
    end
  end
end
