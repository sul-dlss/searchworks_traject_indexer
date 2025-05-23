# frozen_string_literal: true

module Folio
  class MhldBuilder
    def self.build(holdings, holding_summaries, pieces)
      new(holdings, holding_summaries, pieces).build
    end

    def initialize(holdings, holding_summaries, pieces)
      @holdings = holdings
      @holding_summaries = holding_summaries
      @pieces = pieces
    end

    attr_reader :holdings, :holding_summaries, :pieces

    def build
      filtered_holdings.flatten.map do |holding|
        library = holding.dig(:location, 'library', 'code')
        location = holding.dig(:location, 'code')
        public_note = holding.fetch(:note)
        # The acquisitions department would rather not maintain library_has anymore anymore, as it's expensive for staff to keep it up to date.
        # However, it seems like it's require for records like `a2149237` where there is no other way to display the volume 7 is not held.
        library_has = holding.fetch(:library_has)
        latest = latest_received(holding.fetch(:location).fetch('code'))
        [library, location, public_note, library_has, latest].join(' -|- ') if public_note || library_has.present? || latest
      end
    end

    private

    # Remove suppressed records, electronic records, and records with no holdings statement
    def filtered_holdings
      holdings.filter_map do |holding|
        no_holding_statements = (holding.fetch('holdingsStatements') +
                                 holding.fetch('holdingsStatementsForIndexes') +
                                 holding.fetch('holdingsStatementsForSupplements')).compact.empty?
        next if no_holding_statements || holding['suppressFromDiscovery'] ||
                (holding.dig('holdingsType', 'name') ||
                 holding.dig('location', 'effectiveLocation', 'details', 'holdingsTypeName')) == 'Electronic'

        note = holding.fetch('holdingsStatements').compact.find { |statement| statement.key?('note') && !statement.key?('statement') }&.fetch('note')

        library_has_for_holding(holding).map do |library_has|
          {
            id: holding.fetch('id'),
            location: bound_with_parent_or_holding_location(holding),
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
      holding.fetch('holdingsStatements').compact.select { |statement| statement.key?('statement') }.filter_map do |statement|
        display_statement(statement)
      end + statments_for_index(holding) + statements_for_supplements(holding)
    end

    def statments_for_index(holding)
      holding.fetch('holdingsStatementsForIndexes').compact.filter_map { |statement| display_statement(statement) }.map { |v| "Index: #{v}" }
    end

    def statements_for_supplements(holding)
      holding.fetch('holdingsStatementsForSupplements').compact.filter_map { |statement| display_statement(statement) }.map { |v| "Supplement: #{v}" }
    end

    def display_statement(statement)
      [statement['statement'], statement['note']].reject(&:blank?).join(' ').presence
    end

    # @return [String] the latest received piece for a holding
    def latest_received(location_id)
      pieces = pieces_per_location.fetch(location_id, [])
      received_pieces = pieces.select { |piece| piece['receivingStatus'] == 'Received' }
      latest_piece = Holdings.find_latest(received_pieces)

      return unless latest_piece && order_is_ongoing_and_open?(latest_piece)

      enumeration = latest_piece['enumeration'].presence # may not be present
      chronology = latest_piece['chronology'].presence # may not be present
      enumeration && chronology ? "#{enumeration} (#{chronology})" : enumeration || chronology
    end

    def order_is_ongoing_and_open?(latest_piece)
      holding_summary = holding_summaries.find { |summary| summary['poLineId'] == latest_piece['poLineId'] }
      holding_summary && holding_summary['orderType'] == 'Ongoing' && holding_summary['orderStatus'] == 'Open'
    end

    # Look at the journal Nature (hrid: a3195844) as a pathological case (but pieces aren't loaded there yet)
    # hrid: a567006 has > 1000 on test.
    def pieces_per_location
      @pieces_per_location ||= pieces.group_by { |piece| bound_with_parent_or_holding_location(holdings_by_id[piece['holdingId']])&.dig('code') }
    end

    def holdings_by_id
      @holdings_by_id ||= holdings.index_by { |holding| holding['id'] }
    end

    def bound_with_parent_or_holding_location(holding)
      return if holding.nil?

      holding.dig('boundWith', 'item', 'location', 'effectiveLocation') || holding.dig('location', 'effectiveLocation')
    end
  end
end
