require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/enumerable'
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

      item_course = reserves.select { |r| item['barcode'] == reserves.dig('copiedItem', 'barcode') }.map { |reserve| courses.find { |c| reserves['courseListingId'] == c['courseListingId'] } }.uniq.compact.first
      # current_location = ????
      course_id = item_course['courseNumber'] || ''
      rez_desk = item_course.dig('courseListingObject', 'locationObject', 'code') || ''
      loan_period = item['temporaryLoanType']&.sub(/ type$/, '') || ''

      crez_info = [course_id, rez_desk, loan_period]

      SirsiHolding.new(
        call_number: [item.dig('callNumber', 'callNumber'), item['volume']].compact.join(' '),
        current_location: (current_location unless current_location == home_location_code),
        home_location: home_location_code,
        library: library_code,
        scheme: call_number_type_map(item.dig('callNumber', 'typeName')),
        type: item['materialType'],
        barcode: item['barcode'],
        # TODO: not implementing public note (was 999 subfield o) currently
        tag: item,
        crez_info: crez_info
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

  def courses
    @courses ||= begin
      if record['items']
        record['items'].flat_map { |x| x['crez'].map { |cr| cr['course'] } }.uniq { |cr| cr['id'] }
      else
        reserves.pluck('courseListingId').uniq.flat_map do |course_id|
          client.get_json("/coursereserves/courses", params: { query: "courseListingId==#{course_id}" })['courses']
        end
      end
    end
  end

  def items
    (record['items'] || items_and_holdings&.dig('items')&.map { |i| i.merge(reserve_data_for_item(i['id'])) } || []).reject { |item| item['suppressFromDiscovery'] }
  end

  def holdings
    (record['holdings'] || items_and_holdings&.dig('holdings') || []).reject { |holding| holding['suppressFromDiscovery'] }
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

  def reserve_data_for_item(item_uuid)
    reserves.select { |reserve| reserve['item_id'] == item_uuid }.map do |r|
      {
        'reserve' => r,
        'courselisting' => { 'id' => r['courseListingId'] },
        'course' => courses.find { |c| c['courseListingId'] == r['courseListingId'] }
      }
    end
  end

  def reserves
    @reserves ||= begin
      client.get_json("/coursereserves/reserves", params: { query: "copiedItem.instanceId==#{instance_id}" })['reserves']
    end
  end

  def stripped_marc_json
    record.dig('source_record', 0).tap do |record|
      record['fields'] = record['fields'].reject { |field| Constants::JUNK_TAGS.include?(field.keys.first) }
    end
  end
end
