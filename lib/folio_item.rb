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

  SKIPPED_LOCS = %w[SUL-BORROW-DIRECT].freeze

  delegate [:temp_call_number?] => :call_number

  attr_reader :item, :holding, :instance,
              :id, :type, :barcode, :course_reserves, :status

  # rubocop:disable Metrics/ParameterLists
  def initialize(item: nil, holding: nil, instance: nil,
                 course_reserves: [],
                 type: nil, status: nil,
                 library: nil, record: nil, bound_with: false)
    @item = item
    @holding = holding
    @instance = instance
    @id = @item&.dig('id')
    @status = status || item&.dig('status')
    @library = library
    @type = type || @item&.dig('materialType')
    @barcode = @item&.dig('barcode')
    @course_reserves = course_reserves
    @record = record
    @bound_with = bound_with
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
    @public_note ||= (item_notes + (bound_with? ? holding_notes : []))

    @public_note.map { |n| ".#{n[:type]&.upcase}. #{n[:note]}" }&.join("\n")&.presence
  end

  def item_notes
    item&.dig('notes')&.map { |n| { type: n['itemNoteTypeName'], note: n['note'] } } || []
  end

  def holding_notes
    holding&.dig('notes')&.map { |n| { type: n['holdingsNoteTypeName'], note: n['note'] } } || []
  end

  def call_number
    @call_number ||= build_call_number
  end

  def skipped?
    [display_location&.dig('code'), temporary_location_code].intersect?(SKIPPED_LOCS)
  end

  def shelved_by_text
    display_location.dig('details', 'shelvedByText') if display_location&.dig('details', 'shelvedByText').present?
  end

  # From https://okapi-test.stanford.edu/call-number-types?limit=1000&query=cql.allRecords=1%20sortby%20name
  def call_number_type
    @call_number_type ||= self.class.call_number_type_code(item&.dig('callNumberType', 'name') || item&.dig('callNumber', 'typeName') || holding&.dig('callNumberType', 'name') || bound_with&.dig('holding', 'callNumberType', 'name'))
  end

  def ==(other)
    other.is_a?(self.class) and
      other.id == @id
  end

  alias eql? ==

  def hash
    [@item, @holding, @id].hash
  end

  def to_item_display_hash
    {
      id:,
      barcode:,
      library:,
      type:,
      note: public_note.presence,
      instance_id: bound_with&.dig('instance', 'id') || instance&.dig('id'),
      instance_hrid: bound_with&.dig('instance', 'hrid') || instance&.dig('hrid'),
      effective_permanent_location_code: display_location_code,
      temporary_location_code:,
      permanent_location_code: permanent_location&.dig('code'),
      status:,
      # FOLIO data used to drive circulation rules
      effective_location_id: temporary_location&.dig('id') || permanent_location&.dig('id'),
      material_type_id: item&.dig('materialTypeId'),
      loan_type_id: item&.dig('temporaryLoanTypeId') || item&.dig('permanentLoanTypeId'),
      bound_with: bound_with_data,
      is_bound_with_principal: bound_with_principal?
    }.merge(course_reserves_data)
  end

  # The represenation of the bound with that goes on the item_display_struct
  def bound_with_data
    return unless bound_with?

    {
      hrid: bound_with.dig('instance', 'hrid'),
      title: bound_with.dig('instance', 'title'),
      call_number: item.dig('callNumber', 'callNumber'),
      volume: item['volume'],
      enumeration: item['enumeration'],
      chronology: item['chronology']
    }
  end

  def bound_with_principal?
    return false if bound_with? || holding.blank?

    holding['boundWith'].present? && item['id'] == holding['boundWith']['item']['id']
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

  def bound_with
    return unless bound_with?

    holding&.dig('boundWith')
  end

  def bound_with?
    @bound_with && holding&.dig('boundWith').present?
  end

  def equipment?
    holding.dig('holdingsType', 'name') == 'Equipment'
  end

  private

  attr_reader :record

  def temporary_location
    item&.dig('location', 'temporaryLocation')
  end

  def permanent_location
    item&.dig('location', 'permanentLocation') ||
      bound_with&.dig('holding', 'location', 'effectiveLocation') ||
      holding&.dig('location', 'effectiveLocation')
  end

  # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
  def build_call_number
    base_call_number ||= @item&.dig('callNumber', 'callNumber') ||
                         @holding&.dig('callNumber') ||
                         bound_with&.dig('holding', 'callNumber')

    volume_info = normalize_call_number([@item['volume'], @item['enumeration'], @item['chronology']].compact.join(' ').presence) if @item

    if bound_with?
      # bound-withs are a special case; the call number for the holding includes the base call number and any volume information. We can try
      # to extract the volume information from this call number by using the parent item's base call number (but sometimes the parent + child
      # call numbers are different... at least we tried)
      if @item&.dig('callNumber', 'callNumber') && @holding&.dig('callNumber')&.start_with?(@item&.dig('callNumber', 'callNumber'))
        base_call_number = @item&.dig('callNumber', 'callNumber')
        volume_info = @holding&.dig('callNumber')&.delete_prefix(base_call_number)&.strip # rubocop:disable Style/SafeNavigationChainLength
      else
        base_call_number = @holding&.dig('callNumber')
        volume_info = nil
      end
    end

    if volume_info.blank? && (%w[ALPHANUM SUDOC].include?(call_number_type)) && record
      # ALPHANUM call numbers seem to be problematic; sometimes they use the volume/enumeration/chronology fields under one holdings record
      # but sometimes they create unique holdings records for each item... so we get to do a little extra work to try to generate
      # the volume information as best we can...:
      # we assume that all items in the same location with the same call number prefix are part of the same set, so
      # the common prefix between all those call numbers is the base call number, and the differences are the volume info.
      # The prefix is the shared characters from the beginning of the call number up to the first space or punctuation before
      # the call numbers start to diverge.

      all_holdings = record.holdings.select do |x|
        x&.dig('boundWith', 'holding', 'location', 'effectiveLocation', 'id') == holding&.dig('location', 'effectiveLocation', 'id') ||
          x&.dig('location', 'effectiveLocation', 'id') == bound_with&.dig('holding', 'location', 'effectiveLocation', 'id') ||
          x&.dig('location', 'effectiveLocation', 'id') == holding&.dig('location', 'effectiveLocation', 'id')
      end
      callnums_in_the_same_location = all_holdings.filter_map { |x| x&.dig('callNumber') }.select { |cn| cn[0..4] == base_call_number[0..4] }

      prefix = Utils.longest_common_call_number_prefix(*callnums_in_the_same_location)
      if prefix.length > 4
        original_call_number = base_call_number
        base_call_number = prefix.strip
        volume_info = original_call_number.delete_prefix(prefix)
      end
    end

    CallNumber.new(normalize_call_number(base_call_number), call_number_type, volume_info:, library:)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity

  # Call number normalization ported from solrmarc code
  def normalize_call_number(call_number)
    return call_number unless call_number && %w[LC DEWEY SUDOC].include?(call_number_type)

    call_number = call_number.strip.gsub(/\s\s+/, ' ') # reduce multiple whitespace chars to a single space
    call_number = call_number.gsub('. .', ' .') # reduce double periods to a single period
    call_number = call_number.gsub(/(\d+\.) ([A-Z])/, '\1\2') # remove space after a period if period is after digits and before letters
    call_number = call_number.sub(/\.$/, '') # remove trailing period
    call_number = normalize_sudoc_call_number(call_number) if call_number_type == 'SUDOC'
    call_number
  end

  def normalize_sudoc_call_number(call_number)
    stem, suffix = call_number.split(':', 2)
    return call_number unless suffix

    # Drop everything after the first slash or second whitespace in the suffix.
    # This is the best guess at the Sudoc "book number". Consistency/meaning goes way down after this.
    if suffix.include?('/')
      "#{stem}:#{suffix.split('/', 2).first}".strip
    else
      parts = suffix.split(/\s+/, 3)
      parts.size >= 3 ? "#{stem}:#{parts[0]} #{parts[1]}".strip : call_number
    end
  end

  class CallNumber
    VALID_CALDOC_REGEX = /^.*CALIF\s+[A-Z]\s*\d{3,4}/
    VALID_DEWEY_REGEX = /^\d{1,3}(\.\d+)? *\.? *[A-Z]\d{1,3} *[A-Z]*+.*/
    VALID_LC_REGEX = /(^[A-Z&&[^IOWXY]]{1}[A-Z]{0,2} *\d+(\.\d*)?( +([\da-z]\w*)|([A-Z]\D+\w*))?) *\.?[A-Z]\d+.*/
    VALID_UNDOC_REGEX = %r{^(?:[A-Z]{0,10}/\s*.+|ICAO\s*[A-Z]+.*)$}
    TEMP_CALLNUM_PREFIX = 'XX('
    SKIPPED_CALL_NUMS = ['NO CALL NUMBER'].freeze

    attr_reader :base_call_number, :purported_type, :volume_info, :library

    # NOTE: call_number may be nil (when used for an on-order item)
    def initialize(base_call_number, purported_type = nil, volume_info: nil, library: nil)
      @base_call_number = base_call_number
      @purported_type = purported_type
      @volume_info = volume_info
      @library = library
    end

    def type
      @type ||= case purported_type
                when 'LC'
                  if valid_lc?
                    'LC'
                  elsif valid_dewey?
                    'DEWEY'
                  elsif valid_undoc?
                    'UNDOC'
                  else
                    'OTHER'
                  end
                when 'ALPHANUM'
                  if valid_caldoc?
                    'CALDOC'
                  elsif valid_undoc?
                    'UNDOC'
                  else
                    purported_type.upcase
                  end
                else
                  valid_undoc? ? 'UNDOC' : purported_type.upcase
                end
    end

    def <=>(other)
      to_s <=> other.to_s
    end

    def call_number
      separator = volume_info.present? && volume_info.start_with?(/(\s|[[:punct:]])/) ? '' : ' '

      [base_call_number.to_s, volume_info].compact.join(separator)
    end

    def ignored_call_number?
      SKIPPED_CALL_NUMS.include?(call_number.to_s) ||
        temp_call_number?
    end

    def temp_call_number?
      to_s.blank? || to_s.start_with?(TEMP_CALLNUM_PREFIX)
    end

    def shelfkey(serial: false)
      case type
      when 'LC'
        CallNumbers::LcShelfkey.new(base_call_number.to_s, volume_info, serial:)
      when 'DEWEY'
        CallNumbers::DeweyShelfkey.new(base_call_number.to_s, volume_info, serial:)
      when 'SUDOC'
        CallNumbers::SudocShelfkey.new(base_call_number.to_s, volume_info, serial:)
      when 'CALDOC'
        CallNumbers::CaldocShelfkey.new(base_call_number.to_s, volume_info, serial:)
      when 'UNDOC'
        CallNumbers::UndocShelfkey.new(base_call_number.to_s, volume_info, serial:)
      else
        CallNumbers::OtherShelfkey.new(
          base_call_number.to_s,
          volume_info,
          scheme: type,
          serial:
        )
      end
    end

    def to_s
      call_number
    end

    def valid_caldoc?
      call_number&.match?(VALID_CALDOC_REGEX)
    end

    def valid_lc?
      call_number&.match?(VALID_LC_REGEX)
    end

    def valid_undoc?
      call_number&.match?(VALID_UNDOC_REGEX)
    end

    def bad_lc_lane_call_number?
      return false if valid_lc?
      return false if library != 'LANE'
      return false if valid_dewey?

      purported_type == 'LC'
    end

    def classification
      return if ignored_call_number? || bad_lc_lane_call_number?

      if type == 'DEWEY' && valid_dewey?
        call_number.sub(/^\d{1,3}/) { |x| x.rjust(3, '0') }
      elsif type == 'LC' && (lc = (self if valid_lc?) || normalized_lc.valid_lc?)
        lc.to_s[/^[A-Z]{1,3}/]
      end
    end

    private

    def valid_dewey?
      call_number&.match?(VALID_DEWEY_REGEX)
    end

    def normalized_lc
      return unless call_number

      value = call_number.gsub(/\s\s+/, ' ') # change all multiple whitespace chars to a single space
                         .gsub(/\s?\.\s?/, '.') # remove a space before or after a period
                         .gsub(/^([A-Z][A-Z]?[A-Z]?) ([0-9])/, '\1\2') # remove space between class letters and digits

      FolioItem::CallNumber.new(value, purported_type, volume_info:, library:)
    end
  end
end
