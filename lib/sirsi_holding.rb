class SirsiHolding
  BUSINESS_SHELBY_LOCS = %w[NEWS-STKS].freeze
  ECALLNUM = 'INTERNET RESOURCE'.freeze
  SHELBY_LOCS = %w[BUS-PER BUSDISPLAY BUS-MAKENA SHELBYTITL SHELBYSER STORBYTITL].freeze
  SKIPPED_CALL_NUMS = ['NO CALL NUMBER'].freeze
  TEMP_CALLNUM_PREFIX = 'XX'.freeze

  attr_reader :field
  def initialize(field)
    @field = field
  end

  def shelved_by_location?
    if library == 'BUSINESS'
      ([home_location, current_location] & BUSINESS_SHELBY_LOCS).any?
    else
      ([home_location, current_location] & SHELBY_LOCS).any?
    end
  end

  def skipped_call_number?
    SKIPPED_CALL_NUMS.include?(call_number) ||
      call_number.start_with?(ECALLNUM) ||
      temp_call_number?
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
    return false if library != 'LANE-MED'
    return false if self.class.dewey_call_number?(call_number)
    call_number_type == 'LC'
  end

  def call_number
    (field['a'] || '').strip
  end

  def current_location
    field['k']
  end

  def home_location
    field['l']
  end

  def library
    field['m']
  end

  def scheme
    field['w']
  end

  class << self
    DEWEY_CLASS_REGEX = '\d{1,3}(\.\d+)?'.freeze

    # Dewey cutters start with a letter, followed by a one to three digit
    # number. The number may be followed immediately (i.e. without space) by
    # letters, or followed first by a space and then letters.
    DEWEY_MIN_CUTTER_REGEX = '[A-Z]\d{1,3}'.freeze
    DEWEY_CUTTER_TRAILING_LETTERS_REGEX =  "#{DEWEY_MIN_CUTTER_REGEX}[A-Z]+".freeze
    DEWEY_CUTTER_SPACE_TRAILING_LETTERS_REGEX = "#{DEWEY_MIN_CUTTER_REGEX} +[A-Z]+".freeze
    DEWEY_FULL_CUTTER_REGEX = "#{DEWEY_MIN_CUTTER_REGEX} *[A-Z]*+".freeze

    DEWEY_CLASS_N_CUTTER_REGEX = "#{DEWEY_CLASS_REGEX} *\.?#{DEWEY_FULL_CUTTER_REGEX}".freeze
    DEWEY_CLASS_N_CUTTER_PATTERN = /#{DEWEY_CLASS_N_CUTTER_REGEX}.*/

    def dewey_call_number?(call_number)
      call_number.match?(DEWEY_CLASS_N_CUTTER_PATTERN)
    end
  end

  private

  def temp_call_number?
    return false if library == 'HV-ARCHIVE' # Call numbers in HV-ARCHIVE are not temporary

    call_number.start_with?(TEMP_CALLNUM_PREFIX)
  end
end
