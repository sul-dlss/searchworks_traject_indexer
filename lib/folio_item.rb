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
                 library: nil, record: nil)
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
    @record = record
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
      temp_call_number?
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
      loan_type_id: item&.dig('temporaryLoanTypeId') || item&.dig('permanentLoanTypeId'),
      bound_with:
    }.merge(course_reserves_data)
  end

  # The represenation of the bound with that goes on the item_display_struct
  def bound_with
    return unless bound_with_holding

    {
      hrid: bound_with_holding.dig('boundWith', 'instance', 'hrid'),
      title: bound_with_holding.dig('boundWith', 'instance', 'title'),
      call_number: item.dig('callNumber', 'callNumber'),
      volume: item['volume'],
      enumeration: item['enumeration'],
      chronology: item['chronology']
    }
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

  attr_reader :record

  def temporary_location
    item&.dig('location', 'temporaryLocation')
  end

  def permanent_location
    item&.dig('location', 'permanentLocation') ||
      holding&.dig('location', 'effectiveLocation')
  end

  def build_call_number
    base_call_number = @bound_with_holding&.dig('callNumber') ||
                       @item&.dig('callNumber', 'callNumber') ||
                       @holding&.dig('callNumber')

    volume_info = normalize_call_number([@item['volume'], @item['enumeration'], @item['chronology']].compact.join(' ').presence) if @item

    if volume_info.blank? && (call_number_type == 'ALPHANUM' || call_number_type == 'SUDOC') && record
      # ALPHANUM call numbers seem to be problematic; sometimes they use the volume/enumeration/chronology fields under one holdings record
      # but sometimes they create unique holdings records for each item... so we get to do a little extra work to try to generate
      # the volume information as best we can...:
      # we assume that all items in the same location with the same call number prefix are part of the same set, so
      # the common prefix between all those call numbers is the base call number, and the differences are the volume info.
      # The prefix is the shared characters from the beginning of the call number up to the first space or punctuation before
      # the call numbers start to diverge.

      all_holdings = record.holdings.select { |x| x&.dig('location', 'effectiveLocation') == holding&.dig('location', 'effectiveLocation') }
      callnums_in_the_same_location = all_holdings.filter_map { |x| x&.dig('callNumber') }.select { |cn| cn[0..4] == base_call_number[0..4] }

      prefix = Utils.longest_common_call_number_prefix(*callnums_in_the_same_location)
      if prefix.length > 4
        original_call_number = base_call_number
        base_call_number = prefix.strip
        volume_info = original_call_number[prefix.length..].strip
      end
    end

    CallNumber.new(normalize_call_number(base_call_number), call_number_type, volume_info:)
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

    attr_reader :base_call_number, :purported_type, :volume_info

    # NOTE: call_number may be nil (when used for an on-order item)
    def initialize(base_call_number, purported_type = nil, volume_info: nil)
      @base_call_number = base_call_number
      @purported_type = purported_type
      @volume_info = volume_info
    end

    def type
      @type ||= if purported_type == 'LC'
                  if valid_lc?
                    'LC'
                  elsif dewey?
                    'DEWEY'
                  else
                    'OTHER'
                  end
                else
                  purported_type.upcase
                end
    end

    def <=>(other)
      to_s <=> other.to_s
    end

    def call_number
      [base_call_number.to_s, volume_info].compact.join(' ')
    end

    def shelfkey(serial: false)
      case type
      when 'LC'
        CallNumbers::LcShelfkey.new(base_call_number.to_s, volume_info, serial:)
      when 'DEWEY'
        CallNumbers::DeweyShelfkey.new(base_call_number.to_s, volume_info, serial:)
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
