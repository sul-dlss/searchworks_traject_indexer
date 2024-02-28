# frozen_string_literal: true

require 'forwardable'

class FolioItem
  extend Forwardable

  def self.call_number_type_code(folio_call_number_type_name)
    case folio_call_number_type_name
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

  delegate %i[dewey? valid_lc?] => :call_number

  SHELBY_LOCS = %w[BUS-PER BUS-MAKENA BUS-NEWS-STKS SHELBYTITL SCI-SHELBYSERIES].freeze
  SKIPPED_CALL_NUMS = ['NO CALL NUMBER'].freeze
  SKIPPED_LOCS = %w[SUL-BORROW-DIRECT].freeze
  TEMP_CALLNUM_PREFIX = 'XX('

  attr_reader :item, :holding, :instance, :bound_with_holding,
              :id, :type, :barcode, :course_reserves, :status

  # rubocop:disable Metrics/ParameterLists
  def initialize(item: nil, holding: nil, instance: nil,
                 bound_with_holding: nil,
                 course_reserves: [],
                 type: nil, status: nil,
                 library: nil)
    @item = item
    @holding = holding
    @instance = instance
    @bound_with_holding = bound_with_holding
    @id = @item&.dig('id')
    @status = status || item&.dig('status')
    @library = library
    @type = type || @item&.dig('materialType')
    @barcode = @item&.dig('barcode')
    @course_reserves = course_reserves
  end
  # rubocop:enable Metrics/ParameterLists

  def display_location
    return temporary_location if temporary_location&.dig('details', 'searchworksTreatTemporaryLocationAsPermanentLocation') == 'true'

    permanent_location
  end

  def library
    @library ||= display_location&.dig('library', 'code')
  end

  def display_location_code
    display_location&.dig('code')
  end

  def temporary_location_code
    temporary_location&.dig('code')
  end

  def public_note
    @public_note ||= item&.dig('notes')&.map { |n| ".#{n['itemNoteTypeName']&.upcase}. #{n['note']}" }&.join("\n")&.presence
  end

  def call_number
    @call_number ||= build_call_number
  end

  def skipped?
    [display_location&.dig('code'), temporary_location&.dig('code')].intersect?(SKIPPED_LOCS)
  end

  def shelved_by_location?
    [display_location&.dig('code'), temporary_location&.dig('code')].intersect?(SHELBY_LOCS) || display_location&.dig('code')&.end_with?('-SHELBYTITL')
  end

  # From https://okapi-test.stanford.edu/call-number-types?limit=1000&query=cql.allRecords=1%20sortby%20name
  def call_number_type
    @call_number_type ||= self.class.call_number_type_code(item&.dig('callNumberType', 'name') || item&.dig('callNumber', 'typeName') || bound_with_holding&.dig('callNumberType', 'name') || holding&.dig('callNumberType', 'name'))
  end

  def bad_lc_lane_call_number?
    return false if valid_lc?
    return false if library != 'LANE'
    return false if dewey?

    call_number_type == 'LC'
  end

  def ignored_call_number?
    SKIPPED_CALL_NUMS.include?(call_number.to_s) ||
      temp_call_number? ||
      internet_resource?
  end

  def temp_call_number?
    call_number.to_s.blank? || call_number.to_s.start_with?(TEMP_CALLNUM_PREFIX)
  end

  def lost_or_missing?
    status == 'Missing' || status == 'Long missing'
  end

  def in_process?
    temp_call_number? && (status == 'In process' || status == 'In process (non-requestable)')
  end

  def on_order?
    temp_call_number? && status == 'On order'
  end

  def browseable?
    return false if internet_resource? || skipped? || lost_or_missing? || shelved_by_location?

    browseable_schemes.include?(call_number_type)
  end

  def ==(other)
    other.is_a?(self.class) and
      other.id == @id
  end

  alias eql? ==

  def hash
    [@item, @holding, @bound_with_holding, @id].hash
  end

  def to_item_display_hash
    {
      id:,
      barcode:,
      library:,
      home_location: display_location&.dig('code'),
      current_location: temporary_location&.dig('code'),
      type:,
      note: public_note.presence,
      instance_id: instance&.dig('id'),
      instance_hrid: instance&.dig('hrid'),
      # FOLIO item data to replace library/home_location/current_location some day
      effective_permanent_location_code: display_location_code,
      temporary_location_code: temporary_location&.dig('code'),
      permanent_location_code: permanent_location&.dig('code'),
      status:,
      # FOLIO data used to drive circulation rules
      effective_location_id: temporary_location&.dig('id') || permanent_location&.dig('id'),
      material_type_id: item&.dig('materialTypeId'),
      loan_type_id: item&.dig('temporaryLoanTypeId') || item&.dig('permanentLoanTypeId')
    }.merge(course_reserves_data)
  end

  def course_reserves_data
    # NOTE: we don't handle multiple courses for a single item, because it's beyond parity with how things worked for Symphony
    course = course_reserves.first

    return {} unless course && item

    # We use loan types as loan periods for course reserves so that we don't need to check circ rules
    # Items on reserve in FOLIO usually have a temporary loan type that indicates the loan period
    # "3-day reserve" -> "3-day loan"
    {
      reserve_desk: course[:reserve_desk],
      course_id: course[:course_id],
      loan_period: item['temporaryLoanType']&.gsub('reserve', 'loan')
    }
  end

  def internet_resource?
    type == Folio::EresourceHoldingsBuilder::TYPE
  end

  private

  def temporary_location
    item&.dig('location', 'temporaryLocation')
  end

  def permanent_location
    item&.dig('location', 'permanentLocation') ||
      holding&.dig('location', 'effectiveLocation')
  end

  def build_call_number
    provided_call_number = @bound_with_holding&.dig('callNumber') ||
                           @item&.dig('callNumber', 'callNumber') ||
                           @holding&.dig('callNumber')

    CallNumber.new(normalize_call_number(provided_call_number), call_number_type, volume_info: ([@item['volume'], @item['enumeration'], @item['chronology']].compact.join(' ').presence if @item))
  end

  # Call number normalization ported from solrmarc code
  def normalize_call_number(call_number)
    return call_number unless call_number && %w[LC DEWEY].include?(call_number_type) # Normalization only applied to LC/Dewey

    call_number = call_number.strip.gsub(/\s\s+/, ' ') # reduce multiple whitespace chars to a single space
    call_number = call_number.gsub('. .', ' .') # reduce double periods to a single period
    call_number = call_number.gsub(/(\d+\.) ([A-Z])/, '\1\2') # remove space after a period if period is after digits and before letters
    call_number.sub(/\.$/, '') # remove trailing period
  end

  class CallNumber
    BEGIN_CUTTER_REGEX = %r{( +|(\.[A-Z])| */)}
    VALID_DEWEY_REGEX = /^\d{1,3}(\.\d+)? *\.? *[A-Z]\d{1,3} *[A-Z]*+.*/
    VALID_LC_REGEX = /(^[A-Z&&[^IOWXY]]{1}[A-Z]{0,2} *\d+(\.\d*)?( +([\da-z]\w*)|([A-Z]\D+\w*))?) *\.?[A-Z]\d+.*/

    attr_reader :call_number, :purported_type, :volume_info

    # NOTE: call_number may be nil (when used for an on-order item)
    def initialize(call_number, purported_type, volume_info: nil)
      @call_number = call_number
      @purported_type = purported_type
      @volume_info = volume_info
    end

    def type
      @type ||= case purported_type
                when 'LC'
                  if valid_lc?
                    'LC'
                  elsif dewey?
                    'DEWEY'
                  else
                    'OTHER'
                  end
                when 'DEWEY'
                  'DEWEY'
                else
                  'OTHER'
                end
    end

    def <=>(other)
      to_s <=> other.to_s
    end

    def sortable_volume_info
      return unless volume_info
      return volume_info.downcase.strip unless volume_info[/\d+/]

      # prefix all numbers with the count of digits (and the count of digits of the count) so they sort lexically
      volume_info.downcase.gsub(/\d+/) do |val|
        val.length.length.to_s + val.length.to_s + val
      end
    end

    def to_s
      [call_number.to_s, volume_info].compact.join(' ')
    end

    def dewey?
      call_number&.match?(VALID_DEWEY_REGEX)
    end

    def valid_lc?
      call_number&.match?(VALID_LC_REGEX)
    end

    def with_leading_zeros
      raise ArgumentError unless dewey?

      decimal_index = before_cutter.index('.') || 0
      call_number_class = if decimal_index.positive?
                            call_number[0, decimal_index].strip
                          else
                            before_cutter
                          end

      case call_number_class.length
      when 1
        "00#{call_number}"
      when 2
        "0#{call_number}"
      else
        call_number
      end
    end

    def normalized_lc
      return unless call_number

      call_number.gsub(/\s\s+/, ' ') # change all multiple whitespace chars to a single space
                 .gsub(/\s?\.\s?/, '.') # remove a space before or after a period
                 .gsub(/^([A-Z][A-Z]?[A-Z]?) ([0-9])/, '\1\2') # remove space between class letters and digits
    end

    def before_cutter
      call_number[/^.*(?=#{BEGIN_CUTTER_REGEX})/].to_s.strip
    end
  end
end
