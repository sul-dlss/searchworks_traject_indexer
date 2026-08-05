# frozen_string_literal: true

require 'forwardable'

module Indexer
  # Represents an indexed item for a record (from a FOLIO item record, on-order piece, bound-with, etc)
  class Item
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
                   library: nil, record: nil, bound_with_child: false, bound_with_principal: false)
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
      @bound_with_child = bound_with_child
      @bound_with_principal = bound_with_principal
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
      return @bound_with if defined?(@bound_with)

      @bound_with ||= holding&.dig('boundWith') if @bound_with_child
    end

    def bound_with?
      bound_with.present?
    end

    def bound_with_principal?
      @bound_with_principal
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

      return Indexer::CallNumber.new('', '') unless base_call_number.present?

      if @item
        volume_info_parts = [@item['volume'], @item['enumeration'], @item['chronology']].compact
        # For SUDOCs, the volume/enumeration/chronology fields are sometimes duplicated in the call number itself
        volume_info_parts = volume_info_parts.reject { |part| base_call_number.include?(part) } if call_number_type == 'SUDOC'
        volume_info = normalize_call_number(volume_info_parts.join(' ').presence)
      end

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

      Indexer::CallNumber.new(normalize_call_number(base_call_number), call_number_type, volume_info:, library:)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity

    # Call number normalization ported from solrmarc code
    def normalize_call_number(call_number)
      return call_number unless call_number && %w[LC DEWEY SUDOC].include?(call_number_type)

      call_number = call_number.strip.gsub(/\s\s+/, ' ') # reduce multiple whitespace chars to a single space
      call_number = call_number.gsub('. .', ' .') # reduce double periods to a single period
      call_number = call_number.gsub(/(\d+\.) ([A-Z])/, '\1\2') # remove space after a period if period is after digits and before letters
      call_number.sub(/\.$/, '') # remove trailing period
    end
  end
end
