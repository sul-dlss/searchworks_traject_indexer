# frozen_string_literal: true

module Folio
  class Holding
    attr_reader :data, :pieces, :items, :bound_with_principal

    delegate :[], :fetch, :dig, :as_json, :to_json, to: :data

    def self.from_dynamic(holding, items: [], pieces: [], bound_with_principals: [], bound_with_parts: [])
      this_pieces = pieces.select { |p| p['holdingId'] == holding['id'] }
      this_items = items.select { |i| i['holdingsRecordId'] == holding['id'] }
      bound_with_link = bound_with_parts.find { |p| p['holdingsRecordId'] == holding['id'] }
      bound_with_principal = bound_with_principals.find { |p| p.dig('item', 'id') == bound_with_link['itemId'] } if bound_with_link

      new(holding, pieces: this_pieces, items: this_items, bound_with_principal: bound_with_principal)
    end

    def initialize(data, pieces: [], items: [], bound_with_principal: nil)
      @data = data
      # keep the bound-with data in the original data structure (for now) to avoid breaking existings tests + code
      @data = @data.merge('boundWith' => bound_with_principal) if bound_with_principal
      @pieces = pieces
      @items = items
      @bound_with_principal = bound_with_principal
    end

    def electronic?
      data.dig('holdingsType', 'name') == 'Electronic' || location_implied_type_name == 'Electronic'
    end

    def bound_with?
      (data.dig('holdingsType', 'name') || location_implied_type_name) == 'Bound-with' || bound_with_parent_exists?
    end

    def on_order?
      pieces.any? { |p| p['receivingStatus'] == 'Expected' && !p['discoverySuppress'] }
    end

    private

    # Some locations imply a holdings type which override the actual type on the record
    def location_implied_type_name
      data.dig('location', 'effectiveLocation', 'details', 'holdingsTypeName')
    end

    def bound_with_parent_exists?
      return false unless data.dig('boundWith', 'item', 'id')
      return false if data.dig('boundWith', 'item', 'suppressFromDiscovery')

      # bound-with "principals" appear as if they're bound-with themselves. See SW-4330.
      !data.dig('boundWith', 'item', 'id').in?(items.map { |item| item['id'] })
    end
  end
end
