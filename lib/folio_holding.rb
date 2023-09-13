# frozen_string_literal: true

require 'forwardable'

class FolioHolding
  extend Forwardable

  delegate %i[dewey? valid_lc?] => :call_number

  BUSINESS_SHELBY_LOCS = %w[NEWS-STKS].freeze
  ECALLNUM = 'INTERNET RESOURCE'
  GOV_DOCS_LOCS = %w[BRIT-DOCS CALIF-DOCS FED-DOCS INTL-DOCS SSRC-DOCS SSRC-FICHE SSRC-NWDOC].freeze
  LOST_OR_MISSING_LOCS = %w[MISSING].freeze
  SHELBY_LOCS = %w[BUS-PER BUS-MAKENA SHELBYTITL SHELBYSER].freeze
  SKIPPED_CALL_NUMS = ['NO CALL NUMBER'].freeze
  SKIPPED_LOCS = %w[BORROWDIR CDPSHADOW SHADOW SSRC-FIC-S STAFSHADOW TECHSHADOW WITHDRAWN].freeze
  TEMP_CALLNUM_PREFIX = 'XX'

  attr_reader :item, :holding, :bound_with_holding, :id, :scheme, :type, :barcode, :course_reserves

  # rubocop:disable Metrics/ParameterLists
  def initialize(item: nil, holding: nil, bound_with_holding: nil, course_reserves: [],
                 call_number: nil, barcode: nil, type: nil,
                 library: nil, home_location: nil, current_location: nil)
    @item = item
    @holding = holding
    @bound_with_holding = bound_with_holding
    @id = id || @item&.dig('id')
    @provided_call_number = call_number || ([@item.dig('callNumber', 'callNumber'), @item['volume'], @item['enumeration'], @item['chronology']].compact.join(' ') if @item) || @bound_with_holding&.dig('callNumber') || @holding&.dig('callNumber')
    @current_location = current_location
    @home_location = home_location
    @library = library
    @scheme = scheme
    @type = type || @item&.dig('materialType')
    @barcode = barcode || @item&.dig('barcode')
    @public_note = public_note
    @course_reserves = course_reserves
  end
  # rubocop:enable Metrics/ParameterLists

  def library
    @library ||= symphony_location_codes[0]
  end

  def home_location
    @home_location ||= symphony_location_codes[1]
  end

  def current_location
    @current_location ||= symphony_location_codes[2]
  end

  def symphony_location_codes
    @symphony_location_codes ||= begin
      item_location_code = item&.dig('location', 'temporaryLocation', 'code') if item&.dig('location', 'temporaryLocation', 'details', 'searchworksTreatTemporaryLocationAsPermanentLocation') == 'true'
      item_location_code ||= item&.dig('location', 'permanentLocation', 'code')
      item_location_code ||= holding&.dig('location', 'effectiveLocation', 'code')

      library_code, home_location_code = LocationsMap.for(item_location_code)
      _current_library, current_location = LocationsMap.for(item&.dig('location', 'temporaryLocation', 'code'))
      current_location ||= item&.dig('location', 'temporaryLocation', 'code') if item&.dig('location', 'temporaryLocation', 'details', 'availabilityClass')
      current_location ||= Folio::StatusCurrentLocation.new(item).current_location if item

      [library_code, home_location_code, (current_location unless current_location == home_location_code)]
    end
  end

  def public_note
    @public_note ||= item&.dig('notes')&.map { |n| ".#{n['itemNoteTypeName']&.upcase}. #{n['note']}" }&.join("\n")&.presence
  end

  def call_number
    @call_number ||= CallNumber.new(normalize_call_number(@provided_call_number))
  end

  def skipped?
    [home_location, current_location].intersect?(SKIPPED_LOCS)
  end

  def shelved_by_location?
    if library == 'BUSINESS'
      [home_location, current_location].intersect?(BUSINESS_SHELBY_LOCS)
    else
      [home_location, current_location].intersect?(SHELBY_LOCS)
    end
  end

  # From https://okapi-test.stanford.edu/call-number-types?limit=1000&query=cql.allRecords=1%20sortby%20name
  def call_number_type
    @call_number_type ||= case scheme || item&.dig('callNumberType', 'name') || item&.dig('callNumber', 'typeName') || bound_with_holding&.dig('callNumberType', 'name') || holding&.dig('callNumberType', 'name')
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

  def bad_lc_lane_call_number?
    return false if valid_lc?
    return false if library != 'LANE-MED'
    return false if dewey?

    call_number_type == 'LC'
  end

  def ignored_call_number?
    SKIPPED_CALL_NUMS.include?(call_number.to_s) ||
      e_call_number? ||
      temp_call_number?
  end

  def temp_call_number?
    return false if library == 'HV-ARCHIVE' # Call numbers in HV-ARCHIVE are not temporary

    call_number.to_s.blank? || call_number.to_s.start_with?(TEMP_CALLNUM_PREFIX)
  end

  def e_call_number?
    call_number.to_s.start_with?(ECALLNUM)
  end

  def lost_or_missing?
    [home_location, current_location].intersect?(LOST_OR_MISSING_LOCS)
  end

  def gov_doc_loc?
    [home_location, current_location].intersect?(GOV_DOCS_LOCS)
  end

  def in_process?
    temp_call_number? && (current_location == 'INPROCESS' || (!current_location.nil? && home_location != 'ON-ORDER'))
  end

  def on_order?
    temp_call_number? && (current_location == 'ON-ORDER' || (!current_location.nil? && home_location == 'ON-ORDER'))
  end

  def ==(other)
    other.is_a?(self.class) and
      other.call_number == @call_number and
      other.current_location == @current_location and
      other.home_location == @home_location and
      other.library == @library and
      other.scheme == @scheme and
      other.type == @type and
      other.barcode == @barcode
  end

  alias eql? ==

  def hash
    [@item, @holding, @bound_with_holding, @id, @barcode].hash
  end

  def to_item_display_hash
    current_location = self.current_location.presence
    current_location = 'ON-ORDER' if on_order? && current_location && !current_location.empty? && home_location != 'ON-ORDER' && home_location != 'INPROCESS'

    {
      id:,
      barcode:,
      library:,
      home_location:,
      current_location:,
      type:,
      note: public_note.presence
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

  private

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

    attr_reader :call_number

    # NOTE: call_number may be nil (when used for an on-order item)
    def initialize(call_number)
      @call_number = call_number
    end

    def <=>(other)
      to_s <=> other.to_s
    end

    def to_s
      call_number.to_s
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
