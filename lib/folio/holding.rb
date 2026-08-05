# frozen_string_literal: true

module Folio
  class Holding
    attr_reader :data

    delegate :[], :fetch, :dig, :as_json, :to_json, to: :data

    def initialize(data)
      @data = data
    end

    def electronic?
      data.dig('holdingsType', 'name') == 'Electronic' || location_implied_type_name == 'Electronic'
    end

    def bound_with?
      data['boundWith'].present? || (data.dig('holdingsType', 'name') || location_implied_type_name) == 'Bound-with'
    end

    private

    def location_implied_type_name
      data.dig('location', 'effectiveLocation', 'details', 'holdingsTypeName')
    end
  end
end
