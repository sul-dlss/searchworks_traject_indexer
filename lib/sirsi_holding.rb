require 'forwardable'

class SirsiHolding
  extend Forwardable

  delegate [:dewey?, :valid_lc?] => :call_number

  BUSINESS_SHELBY_LOCS = %w[NEWS-STKS].freeze
  CLOSED_LIBS = %w[BIOLOGY CHEMCHMENG MATH-CS].freeze
  ECALLNUM = 'INTERNET RESOURCE'.freeze
  GOV_DOCS_LOCS = %w[BRIT-DOCS CALIF-DOCS FED-DOCS INTL-DOCS SSRC-DOCS SSRC-FICHE SSRC-NWDOC].freeze
  LOST_OR_MISSING_LOCS = %w[ASSMD-LOST LOST-ASSUM LOST-CLAIM LOST-PAID MISSING].freeze
  SHELBY_LOCS = %w[BUS-PER BUSDISPLAY BUS-MAKENA SHELBYTITL SHELBYSER STORBYTITL].freeze
  SKIPPED_CALL_NUMS = ['NO CALL NUMBER'].freeze
  SKIPPED_LOCS = %w[3FL-REF-S BASECALNUM BENDER-S CDPSHADOW DISCARD DISCARD-NS EAL-TEMP-S
                    E-INPROC-S E-ORDER-S E-REQST-S FED-DOCS-S LOCKSS LOST MAPCASES-S MAPFILE-S
                    MISS-INPRO MEDIA-MTXO NEG-PURCH SEL-NOTIF SHADOW SPECA-S SPECAX-S SPECB-S
                    SPECBX-S SPECM-S SPECMED-S SPECMEDX-S SPECMX-S SSRC-FIC-S SSRC-SLS STAFSHADOW
                    TECHSHADOW TECH-UNIQ WEST-7B SUPERSEDE WITHDRAWN].freeze
  TEMP_CALLNUM_PREFIX = 'XX'.freeze

  attr_reader :current_location, :home_location, :library, :scheme, :type, :barcode, :tag
  def initialize(tag: nil, call_number: '', current_location: '', home_location: '', library: '', scheme: '', type: '', barcode: '')
    @call_number = call_number
    @current_location = current_location
    @home_location = home_location
    @library = library
    @scheme = scheme
    @type = type
    @barcode = barcode
    @tag = tag
  end

  def call_number
    @call_number_obj ||= CallNumber.new(normalize_call_number(@call_number))
  end

  def skipped?
    ([home_location, current_location] & SKIPPED_LOCS).any? ||
      type == 'EDI-REMOVE' ||
      physics_not_temp? ||
      CLOSED_LIBS.include?(library)
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

    call_number.to_s.start_with?(TEMP_CALLNUM_PREFIX)
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

  def is_in_process?
    temp_call_number? && (current_location == 'INPROCESS' || (!current_location.nil? && home_location != 'ON-ORDER'))
  end

  def is_on_order?
    temp_call_number? && (current_location == 'ON-ORDER' || (!current_location.nil? && home_location == 'ON-ORDER'))
  end

  def ==(other)
    self.class === other and
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

  private

  # Call number normalization ported from solrmarc code
  def normalize_call_number(call_number = '')
    return call_number unless %w[LC DEWEY].include?(call_number_type) # Normalization only applied to LC/Dewey
    call_number = call_number.strip.gsub(/\s\s+/, ' ') # reduce multiple whitespace chars to a single space
    call_number = call_number.gsub(/\. \./, ' .') # reduce double periods to a single period
    call_number = call_number.gsub(/(\d+\.) ([A-Z])/, "\1\2") # remove space after a period if period is after digits and before letters
    call_number.sub(/\.$/, '') # remove trailing period
  end

  def physics_not_temp?
    library == 'PHYSICS' && ![home_location, current_location].include?('PHYSTEMP')
  end

  class CallNumber
    BEGIN_CUTTER_REGEX = /( +|(\.[A-Z])| *\/)/
    VALID_DEWEY_REGEX = /^\d{1,3}(\.\d+)? *\.? *[A-Z]\d{1,3} *[A-Z]*+.*/
    VALID_LC_REGEX = /(^[A-Z&&[^IOWXY]]{1}[A-Z]{0,2} *\d+(\.\d*)?( +([\da-z]\w*)|([A-Z]\D+[\w]*))?) *\.?[A-Z]\d+.*/

    attr_reader :call_number
    def initialize(call_number)
      @call_number = call_number
    end

    def to_s
      call_number
    end

    def dewey?
      call_number.match?(VALID_DEWEY_REGEX)
    end

    def valid_lc?
      call_number.match?(VALID_LC_REGEX)
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
      call_number.gsub(/\s\s+/, ' ') # change all multiple whitespace chars to a single space
                 .gsub(/\s?\.\s?/, '.') # remove a space before or after a period
                 .gsub(/^([A-Z][A-Z]?[A-Z]?) ([0-9])/, '\1\2') # remove space between class letters and digits
    end

    def before_cutter
      call_number[/^.*(?=#{BEGIN_CUTTER_REGEX})/].to_s.strip
    end
  end
end
