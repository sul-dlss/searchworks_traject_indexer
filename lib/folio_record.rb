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

  # Extend the MARC record with data from the FOLIO instance
  # to create parity with the data contained in the Symphony record.
  # @return [MARC::Record]
  def marc_record
    @marc_record ||= Folio::MarcRecordMapper.build(stripped_marc_json, holdings, instance)
  end

  def sirsi_holdings
    @sirsi_holdings ||= begin
      holdings = item_holdings.concat(bound_with_holdings)
      holdings = eresource_holdings if holdings.empty?

      unless all_items.any?
        holdings = on_order_holdings if holdings.empty?
        holdings = on_order_stub_holdings if holdings.empty?
      end

      holdings
    end
  end

  # From https://okapi-test.stanford.edu/call-number-types?limit=1000&query=cql.allRecords=1%20sortby%20name
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
    holdings.present? ? Folio::MhldBuilder.build(holdings, holding_summaries, pieces) : []
  end

  def items
    all_items.reject do |item|
      item['suppressFromDiscovery']
    end
  end

  def holdings
    @holdings ||= all_holdings.reject do |holding|
      holding['suppressFromDiscovery']
    end
  end

  def holding_summaries
    record['holdingSummaries'] || []
  end

  def pieces
    @pieces ||= record.fetch('pieces') { client.pieces(instance_id:) }.compact
  end

  def statistical_codes
    @statistical_codes ||= instance.fetch('statisticalCodes') do
      my_ids = client.instance(instance_id:).fetch('statisticalCodeIds', [])
      client.statistical_codes.select { |code| my_ids.include?(code['id']) }
    end
  end

  def instance
    record['instance'] || {}
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
    item_courses = items.flat_map do |item|
      item.fetch('courses', []).map do |course|
        {
          course_name: course['name'],
          course_id: course['courseNumber'],
          instructors: course['instructorNames'],
          reserve_desk: course['locationCode']
        }
      end
    end

    item_courses.uniq { |c| c[:course_id] }
  end

  def eresource?
    eresource_holdings.any?
  end

  private

  def item_holdings
    items.filter_map do |item|
      holding = holdings.find { |holding| holding['id'] == item['holdingsRecordId'] }
      next unless holding

      item_location_code = item.dig('location', 'temporaryLocation', 'code') if item.dig('location', 'temporaryLocation', 'details', 'searchworksTreatTemporaryLocationAsPermanentLocation') == 'true'
      item_location_code ||= item.dig('location', 'permanentLocation', 'code')
      item_location_code ||= holding.dig('location', 'effectiveLocation', 'code')

      library_code, home_location_code = LocationsMap.for(item_location_code)
      _current_library, current_location = LocationsMap.for(item.dig('location', 'temporaryLocation', 'code'))
      current_location ||= item.dig('location', 'temporaryLocation', 'code') if item.dig('location', 'temporaryLocation', 'details', 'availabilityClass')
      current_location ||= Folio::StatusCurrentLocation.new(item).current_location

      # NOTE: we don't handle multiple courses for a single item, because it's beyond parity with how things worked for Symphony
      course = courses.first { |course| course[:listing_id] == item['courseListingId'] }

      # We use loan types as loan periods for course reserves so that we don't need to check circ rules
      # Items on reserve in FOLIO usually have a temporary loan type that indicates the loan period
      # "3-day reserve" -> "3-day loan"
      course_reserves = {}
      course_reserves = {
        reserve_desk: course[:reserve_desk],
        course_id: course[:course_id],
        loan_period: item['temporaryLoanType']&.gsub('reserve', 'loan')
      } if course

      FolioHolding.new(
        id: item['id'],
        call_number: [item.dig('callNumber', 'callNumber'), item['volume'], item['enumeration'], item['chronology']].compact.join(' '),
        current_location: (current_location unless current_location == home_location_code).presence,
        home_location: home_location_code,
        library: library_code,
        scheme: call_number_type_map(item.dig('callNumberType', 'name') || item.dig('callNumber', 'typeName')),
        type: item['materialType'],
        barcode: item['barcode'],
        public_note: item['notes']&.map { |n| ".#{n['itemNoteTypeName']&.upcase}. #{n['note']}" }&.join("\n")&.presence,
        course_reserves:
      )
    end
  end

  # since FOLIO Bound-with records don't have items, we generate a SirsiHolding using data from the parent item and child holding,
  # or, if there is no parent item, we generate a stub SirsiHolding from the original bound-with holding.
  # TODO: remove this when we stop using SirsiHoldings
  def bound_with_holdings
    @bound_with_holdings ||= holdings.select { |holding| holding['boundWith'].present? || (holding.dig('holdingsType', 'name') || holding.dig('location', 'effectiveLocation', 'details', 'holdingsTypeName')) == 'Bound-with' }.map do |holding|
      parent_item = holding.dig('boundWith', 'item') || {}
      parent_holding = holding.dig('boundWith', 'holding')
      parent_holding ||= holding

      item_location_code = parent_item.dig('location', 'temporaryLocation', 'code') if parent_item.dig('location', 'temporaryLocation', 'details', 'searchworksTreatTemporaryLocationAsPermanentLocation') == 'true'
      item_location_code ||= parent_item.dig('location', 'permanentLocation', 'code')
      item_location_code ||= parent_holding.dig('location', 'effectiveLocation', 'code')

      library_code, home_location_code = LocationsMap.for(item_location_code)
      _current_library, current_location = LocationsMap.for(parent_item.dig('location', 'temporaryLocation', 'code'))
      current_location ||= Folio::StatusCurrentLocation.new(parent_item).current_location

      FolioHolding.new(
        id: parent_item['id'],
        call_number: holding['callNumber'],
        scheme: call_number_type_map(holding.dig('callNumberType', 'name')),
        # parent item's barcode
        barcode: parent_item['barcode'] || "#{hrid.sub(/^a/, '')}-#{(all_holdings.index(holding) + 1).to_s.ljust(3, '0')}1",
        # parent item's current location or SEE-OTHER (SAL3)
        # For the SAL3 logic, see https://consul.stanford.edu/display/MD/Bound+withs
        # When the bound-with item is in SAL3, both the Home and Current Locations on the child records should always be SEE-OTHER.
        current_location: library_code == 'SAL3' ? nil : (current_location unless current_location == home_location_code).presence,
        # parent item's permanent location or SEE-OTHER (SAL3)
        home_location: library_code == 'SAL3' ? 'SEE-OTHER' : home_location_code,
        # parent item's library
        library: library_code
      )
    end
  end

  def eresource_holdings
    @eresource_holdings ||= Folio::EresourceHoldingsBuilder.build(hrid, holdings, marc_record)
  end

  def on_order_holdings
    on_order_holdings = holdings.select do |holding|
      pieces.any? { |p| p['holdingId'] == holding['id'] && p['receivingStatus'] == 'Expected' && !p['discoverySuppress'] }
    end

    on_order_holdings.uniq { |holding| holding.dig('location', 'effectiveLocation', 'code') }.map do |holding|
      library_code, home_location_code = LocationsMap.for(holding.dig('location', 'effectiveLocation', 'code'))

      FolioHolding.new(
        barcode: nil,
        call_number: holding['callNumber'],
        scheme: call_number_type_map(holding.dig('callNumberType', 'name')),
        current_location: 'ON-ORDER',
        home_location: home_location_code,
        library: library_code
      )
    end
  end

  def on_order_stub_holdings
    order_libs = Traject::MarcExtractor.cached('596a', alternate_script: false).extract(marc_record)
    translation_map = Traject::TranslationMap.new('library_on_order_map')

    lib_codes = order_libs.flat_map(&:split).map { |order_lib| translation_map[order_lib] }.uniq
    # exclude generic SUL if there's a more specific library
    lib_codes -= ['SUL'] if lib_codes.length > 1
    lib_codes.map do |lib|
      FolioHolding.new(
        barcode: nil,
        call_number: nil,
        scheme: nil,
        library: lib,
        home_location: 'ON-ORDER',
        current_location: 'ON-ORDER'
      )
    end
  end

  # @param [String] type either 'items' or 'holdings'
  # @return [Array] list of records, of the specified type
  def load(type)
    (record[type] || items_and_holdings&.dig(type) || []).compact
  end

  def all_items
    @all_items ||= load('items')
  end

  def all_holdings
    @all_holdings ||= load('holdings')
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
    Folio::MarcRecordInstanceMapper.build(instance, holdings)
  end
end
# rubocop:enable Metrics/ClassLength
