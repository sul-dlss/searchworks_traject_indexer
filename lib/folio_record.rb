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

  def index_items
    @index_items ||= begin
      items = item_holdings.concat(bound_with_holdings)

      unless all_items.any? || eresource?
        items = on_order_holdings if items.empty?
        items = on_order_stub_holdings if items.empty?
      end

      items
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
    item_courses = all_items.flat_map do |item|
      item.fetch('courses', []).map do |course|
        {
          course_name: course['name'],
          course_id: course['courseNumber'],
          folio_course_id: course['id'],
          instructors: Array(course['instructorNames']), # NOTE: we've seen cases where instructorNames is nil.
          reserve_desk: course['locationCode']
        }
      end
    end

    item_courses.uniq { |c| c[:course_id] }
  end

  def eresource?
    return false unless electronic_holdings.any?

    (marc_record || []).any? { |field| %w[856 956].include?(field.tag) && field.codes.include?('u') }
  end

  def electronic_holdings
    holdings.select { |h| h.dig('holdingsType', 'name') == 'Electronic' || h.dig('location', 'effectiveLocation', 'details', 'holdingsTypeName') == 'Electronic' }
  end

  private

  def item_holdings
    items.filter_map do |item|
      holding = holdings.find { |holding| holding['id'] == item['holdingsRecordId'] }
      next unless holding

      FolioItem.new(
        item:,
        holding:,
        instance:,
        course_reserves: courses.select { |c| c[:listing_id] == item['courseListingId'] },
        record: self
      )
    end
  end

  # since FOLIO Bound-with records don't have items, we generate a FolioItem using data from the parent
  # item and child holding, or, if there is no parent item, we generate a stub FolioItem from the original
  # bound-with holding.
  def bound_with_holdings
    @bound_with_holdings ||= holdings.select { |holding| holding['boundWith'].present? || (holding.dig('holdingsType', 'name') || holding.dig('location', 'effectiveLocation', 'details', 'holdingsTypeName')) == 'Bound-with' }.map do |holding|
      parent_item = holding.dig('boundWith', 'item') || {}
      parent_holding = holding.dig('boundWith', 'holding') || holding

      FolioItem.new(
        item: parent_item,
        holding: parent_holding,
        instance: holding.dig('boundWith', 'instance'),
        bound_with_holding: holding,
        record: self
      )
    end
  end

  def on_order_holdings
    on_order_holdings = holdings.select do |holding|
      pieces.any? { |p| p['holdingId'] == holding['id'] && p['receivingStatus'] == 'Expected' && !p['discoverySuppress'] }
    end

    on_order_holdings.uniq { |holding| holding.dig('location', 'effectiveLocation', 'code') }.map do |holding|
      FolioItem.new(
        holding:,
        instance:,
        status: 'On order',
        record: self
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
      FolioItem.new(
        instance:,
        library: lib,
        status: 'On order',
        record: self
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
