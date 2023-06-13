# frozen_string_literal: true

require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/enumerable'

# rubocop:disable Metrics/ClassLength
class FolioRecord
  attr_reader :record, :client

  delegate :fields, :each, :[], :leader, :tags, :select, :find_all, :to_hash, to: :marc_record

  # @param [Hash<String,Object>] record
  # @param [FolioClient] client
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

  # @param [Hash<String,Object>] record
  # @param [FolioClient] client (nil)
  def initialize(record, client = nil)
    @record = record
    @client = client
  end

  def instance_id
    instance['id']
  end

  def hrid
    instance['hrid']
  end

  def marc_record
    @marc_record ||= begin
      record ||= MARC::Record.new_from_hash(stripped_marc_json || instance_derived_marc_record)

      # if 590 with Bound-with related subfields are present, return the record as is
      field590 = record.find { |f| f.tag == '590' }
      subfield_a = field590&.find { |sf| sf.code == 'a' }
      subfield_c = field590&.find { |sf| sf.code == 'c' }
      unless field590 && subfield_a && subfield_c
        # if 590 or one of its Bound-with related subfields is missing, and FOLIO says this record is Bound-with, append the relevant data from FOLIO
        parents ||= bound_with_parents
        # if Bound-with parents are found, edit the marc record
        if parents&.any?
          # append a new 590 and/or its subfields if not present
          parents.each do |parent|
            field590 = MARC::DataField.new('590', ' ', ' ') if field590.nil?
            field590.subfields << MARC::Subfield.new('a', "#{parent['childHoldingCallNumber']} bound with #{parent['parentInstanceTitle']}") if subfield_a.nil?
            field590.subfields << MARC::Subfield.new('c', "#{parent['parentInstanceId']} (parent record)") if subfield_c.nil?
            record.append(field590)
          end
        end
      end
      record
    end
  end

  def sirsi_holdings
    @sirsi_holdings ||= items.map do |item|
      holding = holdings.find { |holding| holding['id'] == item['holdingsRecordId'] }
      item_location_code = item.dig('location', 'permanentLocation', 'code')
      item_location_code ||= holding.dig('location', 'permanentLocation', 'code')
      library_code, home_location_code = LocationsMap.for(item_location_code)
      _current_library, current_location = LocationsMap.for(item.dig('location', 'location', 'code'))

      SirsiHolding.new(
        call_number: [item.dig('callNumber', 'callNumber'), item['enumeration']].compact.join(' '),
        current_location: (current_location unless current_location == home_location_code),
        home_location: home_location_code,
        library: library_code,
        scheme: call_number_type_map(item.dig('callNumberType', 'name')),
        type: item['materialType'],
        barcode: item['barcode'],
        public_note: item['notes']&.map { |n| ".#{n['itemNoteTypeName']&.upcase}. #{n['note']}" }&.join("\n"),
        tag: item
      )
    end.concat(bound_with_holdings)
  end

  # since FOLIO Bound-with records don't have items, we generate a SirsiHolding using data from the parent item and child holding
  # TODO: remove this when we stop using SirsiHoldings
  def bound_with_holdings
    return [] unless record['boundWithParents']

    @bound_with_holdings ||= holdings.filter { |holding| holding['holdingsType'].is_a?(Hash) ? holding.dig('holdingsType', 'name') == 'Bound-with' : holding['holdingsType'] == 'Bound-with' }.filter_map do |holding|
      parent_item = record['boundWithParents'].find { |parent| parent['childHoldingId'] == holding['id'] }
      next unless parent_item

      parent_item_perm_location = parent_item.dig('parentItemLocation', 'permanentLocation', 'code')
      library_code, home_location_code = LocationsMap.for(parent_item_perm_location)
      _current_library, current_location = LocationsMap.for(parent_item.dig('parentItemLocation', 'effectiveLocation', 'code'))
      SirsiHolding.new(
        call_number: holding['callNumber'],
        scheme: call_number_type_map(holding.dig('callNumberType', 'name')),
        tag: {},
        # parent item's barcode
        barcode: parent_item['parentItemBarcode'],
        # parent item's current location or SEE-OTHER (SAL3)
        # For the SAL3 logic, see https://consul.stanford.edu/display/MD/Bound+withs
        # When the bound-with item is in SAL3, both the Home and Current Locations on the child records should always be SEE-OTHER.
        current_location: library_code == 'SAL3' ? '' : (current_location unless current_location == home_location_code),
        # parent item's permanent location or SEE-OTHER (SAL3)
        home_location: library_code == 'SAL3' ? 'SEE-OTHER' : home_location_code,
        # parent item's library
        library: library_code
      )
    end
  end

  def eresource_holdings
    Folio::EresourceHoldingsBuilder.build(hrid, holdings, marc_record)
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

  # Creates the mhld_display value. This drives the holding display in searchworks.
  # This packed format mimics how we indexed this data when we used Symphony.
  def mhld
    holdings.present? ? Folio::MhldBuilder.build(holdings, pieces) : []
  end

  def items
    @items ||= load('items').reject { |item| item['suppressFromDiscovery'] }
  end

  def items_all_suppressed?
    load('items').any? && load('items').all? { |item| item['suppressFromDiscovery'] }
  end

  def holdings
    @holdings ||= load('holdings').reject { |item| item['suppressFromDiscovery'] }
  end

  def pieces
    @pieces ||= record.fetch('pieces') { client.pieces(instance_id:) }.compact
  end

  def instance
    record['instance'] || {}
  end

  def bound_with_parents
    record['boundWithParents'] || []
  end

  # hash representation of the record
  def as_json
    record
  end

  def to_honeybadger_context
    { hrid:, instance_id: }
  end

  # Course information for any courses that have this record's items on reserve
  # @return [Array<Hash>] course information
  def courses
    record.fetch('courses', []).map do |course|
      {
        course_name: course['name'],
        course_id: course['courseNumber'],
        instructors: course['instructorObjects'].pluck('name')
      }
    end
  end

  private

  # @param [String] type either 'items' or 'holdings'
  # @return [Array] list of records, of the specified type
  def load(type)
    (record[type] || items_and_holdings&.dig(type) || []).compact
  end

  def items_and_holdings
    @items_and_holdings ||= client.items_and_holdings(instance_id:)
  end

  def stripped_marc_json
    return unless record.dig('source_record', 0)

    record.dig('source_record', 0).tap do |record|
      record['fields'] = record['fields'].reject { |field| Constants::JUNK_TAGS.include?(field.keys.first) }
    end
  end

  def instance_derived_marc_record
    MARC::Record.new.tap do |marc|
      marc.append(MARC::ControlField.new('001', hrid))
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
      # instanceTypeId
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
      # date updated
    end.to_hash
  end
end
# rubocop:enable Metrics/ClassLength
