# frozen_string_literal: true

module Folio
  class Holdings
    # This regex expression is used in scanning strings for years
    YEAR_REGEX = /(?:18|19|20)\d{2}/

    # We've seen chronologies that looks like full dates, MON YYYY, WIN YYYY, and nil
    # We've also seen chronologies with slashes designating a range
    # Note that enumeration is not always present. See a591005
    def self.find_latest(holdings)
      # NOTE: We saw some piece records without 'chronology'. Was this just test data?
      pieces = holdings.filter_map do |piece|
        piece.merge(sortable_date: sortable_date(piece),
                    sortable_tokens: sortable_tokens(piece))
      end
      pieces.max_by { |piece| [piece.fetch(:sortable_date), piece.fetch(:sortable_tokens), piece.fetch('enumeration', '')] }
    end

    # @return [Date] a date derived from chronology, enumeration or a really old date (sorts to back) if none are found
    def self.sortable_date(piece)
      SortableDateParser.extract_sortable_date(piece['chronology']) ||
        SortableDateParser.extract_sortable_date(piece['enumeration']) ||
        Date.parse('1000-01-01')
    end

    # @return [Array<Integer>] a list of integer tokens derived from chronology and enumeration.
    def self.sortable_tokens(piece)
      Array(
        extract_sortable_tokens(piece['chronology']) ||
          extract_sortable_tokens(piece['enumeration'])
      )
    end

    # Look for other tokens, which are not dates, that can be used to sort.
    # We need to exclude dates so this field can be used as a tie-breaker
    def self.extract_sortable_tokens(str)
      return unless str.present?

      tokens = str.scan(/\d+/).grep_v(YEAR_REGEX)
      tokens.map(&:to_i) if tokens.present?
    end
  end
end
