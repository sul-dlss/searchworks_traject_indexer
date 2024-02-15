# frozen_string_literal: true

module Folio
  # Folio::EresourceHoldingsBuilder builds an array of FolioHolding
  # instances for electronic resources from FOLIO record components
  class EresourceHoldingsBuilder
    CALL_NUMBER = 'INTERNET RESOURCE'
    TYPE = 'ONLINE'

    def self.build(hrid, holdings, marc_record)
      new(hrid, holdings, marc_record).build
    end

    attr_reader :hrid, :holdings, :marc_record

    def initialize(hrid, holdings, marc_record)
      @hrid = hrid
      @holdings = holdings
      @marc_record = marc_record
    end

    def build
      # If there isn't a holding with an electronic holding code
      # we assume the fulltext link supplements a physical item,
      # like a PURL or HathiTrust link and we don't need to do anything.
      return [] unless electronic_holding_location

      fields = fulltext_links
      fields = electronic_location_fields.first(1) if fields.empty?

      fields.map.with_index do |_url, index|
        folio_holding(index)
      end
    end

    private

    def fulltext_links
      electronic_location_fields.select do |field|
        MarcLinks::Processor.new(field).link_is_fulltext?
      end
    end

    def electronic_location_fields
      (marc_record || []).select { |field| %w[856 956].include?(field.tag) && field.codes.include?('u') }
    end

    def folio_holding(index)
      FolioHolding.new(
        call_number: CALL_NUMBER,
        item: { 'barcode' => barcode(index) },
        holding: electronic_holding_location,
        type: TYPE
      )
    end

    def barcode(index)
      "#{hrid.sub(/^a/, '')}-#{(1000 + index + 1).to_s.rjust(4, '0')}"
    end

    # This finds the first holding matching an online location code.
    # This approach works fine unless there are records with multiple
    # e-resource holdings associated with different locations.
    def electronic_holding_location
      @electronic_holding_location ||= holdings&.find { |h| (h.dig('holdingsType', 'name') || h.dig('location', 'effectiveLocation', 'details', 'holdingsTypeName')) == 'Electronic' }
    end
  end
end
