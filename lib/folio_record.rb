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
    @marc_record ||= MARC::Record.new_from_hash(stripped_marc_json || instance_derived_marc_record)
  end

  def instance_id
    instance['id']
  end

  def hrid
    instance['hrid']
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
    (record['items'] || items_and_holdings&.dig('items') || []).compact.reject { |item| item['suppressFromDiscovery'] }
  end

  def holdings
    (record['holdings'] || items_and_holdings&.dig('holdings') || []).compact.reject { |holding| holding['suppressFromDiscovery'] }
  end

  def instance
    record['instance'] || {}
  end

  def as_json
    record
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
    return unless record.dig('source_record', 0)

    record.dig('source_record', 0).tap do |record|
      record['fields'] = record['fields'].reject { |field| Constants::JUNK_TAGS.include?(field.keys.first) }
    end
  end

  def instance_derived_marc_record
    MARC::Record.new.tap do |marc|
      marc.append(MARC::ControlField.new('001', record.dig('instance', 'hrid')))
      # mode of issuance
      # identifiers
      record.dig('instance', 'languages').each do |l|
        marc.append(MARC::DataField.new('041', ' ', ' ', ['a', l]))
      end

      record.dig('instance', 'contributors').each do |contrib|
        # personal name: 100/700
        field = MARC::DataField.new(contrib['primary'] ? '100' : '700', '1', '')
        # corp. name: 110/710, ind1: 2
        # meeting name: 111/711, ind1: 2
        field.append(MARC::Subfield.new('a', contrib['name']))

        marc.append(field)
      end

      marc.append(MARC::DataField.new('245', '0', '0', ['a', record.dig('instance', 'title')]))

      # alt titles
      record.dig('instance', 'editions').each do |edition|
        marc.append(MARC::DataField.new('250', '0', '', ['a', edition]))
      end
      #instanceTypeId
      record.dig('instance', 'publication').each do |pub|
        field = MARC::DataField.new('264', '0', '0')
        field.append(MARC::Subfield.new('a', pub['place'])) if pub['place']
        field.append(MARC::Subfield.new('b', pub['publisher'])) if pub['publisher']
        field.append(MARC::Subfield.new('c', pub['dateOfPublication'])) if pub['dateOfPublication']
        marc.append(field)
      end
      record.dig('instance', 'physicalDescriptions').each do |desc|
        marc.append(MARC::DataField.new('300', '0', '0', ['a', desc]))
      end
      record.dig('instance', 'publicationFrequency').each do |freq|
        marc.append(MARC::DataField.new('310', '0', '0', ['a', freq]))
      end
      record.dig('instance', 'publicationRange').each do |range|
        marc.append(MARC::DataField.new('362', '0', '', ['a', range]))
      end
      record.dig('instance', 'notes').each do |note|
        marc.append(MARC::DataField.new('500', '0', '', ['a', note['note']]))
      end
      record.dig('instance', 'series').each do |series|
        marc.append(MARC::DataField.new('490', '0', '', ['a', series]))
      end
      # 856 stuff

      record.dig('instance', 'subjects').each do |subject|
        marc.append(MARC::DataField.new('653', '', '', ['a', subject]))
      end
      # nature of content
      marc.append(MARC::DataField.new('999', '', '', ['i', record.dig('instance', 'id')]))
      # date creaetd
      #date updated
    end.to_hash
  end
end
