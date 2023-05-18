# frozen_string_literal: true

module Folio
  class MhldBuilder
    def self.build(holdings, pieces)
      new(holdings, pieces).build
    end

    def initialize(holdings, pieces)
      @holdings = holdings
      @pieces = pieces
    end

    attr_reader :holdings, :pieces

    def build
      filtered_holdings.flatten.map do |holding|
        library, location = LocationsMap.for(holding.fetch(:location).fetch('code'))
        public_note = holding.fetch(:note)
        # The acquisitions department would rather not maintain library_has anymore anymore, as it's expensive for staff to keep it up to date.
        # However, it seems like it's require for records like `a2149237` where there is no other way to display the volume 7 is not held.
        library_has = holding.fetch(:library_has)
        latest = latest_received(holding.fetch(:id))
        [library, location, public_note, library_has, latest].join(' -|- ') if public_note || library_has.present? || latest
      end
    end

    private

    # Remove suppressed record and electronic records
    def filtered_holdings
      holdings.filter_map do |holding|
        next if holding.discovery_suppress || holding.holdings_type.name == 'Electronic'

        note = holding.holdings_statements.find { |statement| statement.note && !statement.statement }&.note

        library_has_for_holding(holding).map do |library_has|
          {
            id: holding.id,
            location: holding.effective_location,
            note:,
            library_has:
          }
        end
      end
    end

    # @return [Array<String>] either the list of statements, a list with a single empty string if there are no statements.
    def library_has_for_holding(holding)
      library_has_array = statements_for_holding(holding)
      library_has_array.empty? ? [''] : library_has_array
    end

    # @return [Array<String>] the list of statements
    def statements_for_holding(holding)
      holding.holdings_statements.select(&:statement).map do |statement|
        if statement.note.present?
          "#{statement.statement} #{statement.note}"
        else
          statement.statement
        end
      end + statments_for_index(holding) + statements_for_supplements(holding)
    end

    def statments_for_index(holding)
      holding.holdings_statements_for_indexes.filter_map { |statement| "Index: #{statement.statement}" if statement.statement }
    end

    def statements_for_supplements(holding)
      holding.holdings_statements_for_supplements.filter_map { |statement| "Supplement: #{statement.statement}" if statement.statement }
    end

    # @return [String] the latest received piece for a holding
    def latest_received(holding_id)
      # NOTE: We saw some piece records without 'chronology'. Was this just test data?
      pieces = pieces_per_holding.fetch(holding_id, []).filter_map { |piece| piece.merge(date: Date.parse(piece.fetch('chronology'))) if piece['chronology'] }
      latest_piece = pieces.max_by { |piece| piece.fetch(:date) }
      "#{latest_piece.fetch('enumeration')} (#{latest_piece.fetch('chronology')})" if latest_piece
    end

    # Look at the journal Nature (hrid: a3195844) as a pathological case (but pieces aren't loaded there yet)
    # hrid: a567006 has > 1000 on test.
    def pieces_per_holding
      @pieces_per_holding ||= pieces.group_by { |piece| piece['holdingId'] }
    end
  end
end
