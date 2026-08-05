# frozen_string_literal: true

module Indexer
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

      self.class.new(value, purported_type, volume_info:, library:)
    end
  end
end
