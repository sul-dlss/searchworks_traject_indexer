# frozen_string_literal: true

module Folio
  # Folio::EresourceHoldingsBuilder builds an array of SirsiHolding
  # instances for electronic resources from FOLIO record components,
  # matching what we would expect to see in a Sirsi record.
  class EresourceHoldingsBuilder
    CALL_NUMBER = 'INTERNET RESOURCE'
    TYPE = 'ONLINE'
    ONLINE_LOCATION_CODES = %w[BUS-ELECTRONIC
                               BUS-SDR
                               HILA-ELECTRONIC
                               HILA-SDR
                               LANE-ECOLL
                               LANE-ECOMP
                               LANE-EDATA
                               LANE-EDOC
                               LANE-EPER
                               LANE-IMAGE
                               LANE-ISIIF
                               LANE-MOBI
                               LAW-ELECTRONIC
                               LAW-SDR
                               SUL-ELECTRONIC
                               SUL-SDR].freeze

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
      return [] unless electronic_holding_location_code

      fields = fulltext_links
      fields = electronic_location_fields.first(1) if fields.empty?

      fields.map.with_index do |_url, index|
        item = marc_item(index)
        SirsiHolding.new(
          call_number: item['a'],
          barcode: item['i'],
          home_location: item['l'],
          library: item['m'],
          type: item['t'],
          tag: item
        )
      end
    end

    private

    def fulltext_links
      electronic_location_fields.select do |field|
        MarcLinks::Processor.new(field).link_is_fulltext? &&
          field.subfields.none? { |sf| sf.code == 'u' && MarcLinks::GSB_URL_REGEX.match?(sf.value) }
      end
    end

    def electronic_location_fields
      (marc_record || []).select { |field| %w[856 956].include?(field.tag) && field.codes.include?('u') }
    end

    def marc_item(index)
      MARC::DataField.new('999', ' ', ' ',
                          ['a', CALL_NUMBER],
                          ['i', barcode(index)],
                          ['l', home_location_code],
                          ['m', library_code],
                          ['t', TYPE])
    end

    def barcode(index)
      "#{hrid.sub(/^a/, '')}-#{(1000 + index + 1).to_s.rjust(4, '0')}"
    end

    def home_location_code
      mapped_location_codes.last
    end

    def library_code
      mapped_location_codes.first
    end

    def mapped_location_codes
      @mapped_location_codes ||= LocationsMap.for(electronic_holding_location_code)
    end

    # This finds the first holding matching an online location code.
    # This approach works fine unless there are records with multiple
    # e-resource holdings associated with different locations.
    def electronic_holding_location_code
      @electronic_holding_location_code ||=
        (holdings || []).map { |h| h.dig('location', 'permanentLocation', 'code') }
                        .find { |c| ONLINE_LOCATION_CODES.include?(c) }
    end
  end
end
