# frozen_string_literal: true

require 'forwardable'

class SirsiHolding
  extend Forwardable

  delegate %i[dewey? valid_lc?] => :call_number

  BUSINESS_SHELBY_LOCS = %w[NEWS-STKS].freeze
  ECALLNUM = 'INTERNET RESOURCE'.freeze
  GOV_DOCS_LOCS = %w[BRIT-DOCS CALIF-DOCS FED-DOCS INTL-DOCS SSRC-DOCS SSRC-FICHE SSRC-NWDOC].freeze
  LOST_OR_MISSING_LOCS = %w[ASSMD-LOST LOST-ASSUM LOST-CLAIM LOST-PAID MISSING].freeze
  SHELBY_LOCS = %w[BUS-PER BUS-MAKENA SHELBYTITL SHELBYSER].freeze
  SKIPPED_CALL_NUMS = ['NO CALL NUMBER'].freeze
  SKIPPED_LOCS = %w[BORROWDIR CDPSHADOW SHADOW SSRC-FIC-S STAFSHADOW TECHSHADOW WITHDRAWN].freeze
  TEMP_CALLNUM_PREFIX = 'XX'.freeze

  attr_reader :id, :current_location, :home_location, :library, :scheme, :type, :barcode, :public_note, :course_reserves

  # rubocop:disable Metrics/ParameterLists
  def initialize(call_number:, home_location:, library:, barcode:, scheme: nil, current_location: nil,
                 id: nil, type: nil, public_note: nil, course_reserves: {})
    @id = id
    @call_number = call_number
    @current_location = current_location
    @home_location = home_location
    @library = library
    @scheme = scheme
    @type = type
    @barcode = barcode
    @public_note = public_note
    @course_reserves = course_reserves
  end
  # rubocop:enable Metrics/ParameterLists

  def call_number
    @call_number_obj ||= CallNumber.new(normalize_call_number(@call_number))
  end

  def skipped?
    ([home_location, current_location] & SKIPPED_LOCS).any?
  end

  def shelved_by_location?
    if library == 'BUSINESS'
      ([home_location, current_location] & BUSINESS_SHELBY_LOCS).any?
    else
      ([home_location, current_location] & SHELBY_LOCS).any?
    end
  end

  def call_number_type
    case scheme
    when /^LC/
      'LC'
    when /^DEWEY/
      'DEWEY'
    when 'SUDOC'
      'SUDOC'
    when 'ALPHANUM'
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
    ([home_location, current_location] & LOST_OR_MISSING_LOCS).any?
  end

  def gov_doc_loc?
    ([home_location, current_location] & GOV_DOCS_LOCS).any?
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
    @call_number.hash ^ @current_location.hash ^ @home_location.hash ^ @library.hash ^ @scheme.hash ^ @type.hash ^ @barcode.hash
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
    }.merge(course_reserves)
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
      call_number_class = if decimal_index > 0
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
