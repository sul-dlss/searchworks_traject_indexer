# frozen_string_literal: true

require 'csv'

# This starts with the location.tsv file provided by libsys. We make any modifications to that data here.
class LocationsMap
  include Singleton

  # FOLIO location codes that are mapped, but we want to handle as FOLIO codes in SearchWorks.
  LOCATIONS_TO_SKIP = %w[SUL-TS-MAINTENANCE
                         SUL-TS-PROCESSING
                         SUL-TS-COLLECTIONCARE
                         SUL-TS-CC-SPECIALPROJECTS
                         SUL-TS-CC-REPAIR
                         SUL-TS-CC-KASEMAKE
                         SUL-TS-CC-BOOKJACKET
                         SUL-TS-CC-BINDERYPREP].freeze

  # Symphony location codes to definitely not map to; these are
  # often locations that have been consolidated in FOLIO and these
  # are the less-prefered mappings for backwards compatibility because
  # they carry additional implications (e.g. being shadowed)
  SYMPHONY_CODES_TO_SKIP = [
    %w[ENG SHELBYTITL],
    %w[GREEN SSRC-FIC-S],
    %w[GREEN FED-DOCS-S],
    %w[GREEN HAS-DIGIT],
    %w[GREEN STAFF],
    %w[HOOVER TURKISH],
    %w[HOOVER PERSIAN],
    %w[HOOVER ARABIC],
    %w[LANE LANE-NEW],
    %w[LAW LAW-ARCHIV],
    %w[LAW LAW-STAFSHADOW],
    %w[MUS MEMLIBMUS],
    %w[RUMSEYMAP RUMXEMPLAR],
    %w[SAL3 INPROCESS],
    %w[SAL3 CDL],
    %w[SAL3 ON-ORDER],
    %w[SPEC-COLL SPECMED-S],
    %w[SPEC-COLL SPECM-S],
    %w[SPEC-COLL SPECB-S],
    %w[SPEC-COLL UARCHX-30],
    %w[SPEC-COLL SPECA-S],
    %w[SUL UNKNOWN],
    %w[RUMSEYMAP W7-STKS]
  ].freeze

  # @return a tuple of library code and location code
  def self.for(key)
    instance.data[key]
  end

  def data
    @data ||= load_map
  end

  def load_map
    load_home_locations.merge(load_current_locations)
  end

  def load_home_locations
    CSV.parse(File.read(File.join(__dir__, 'translation_maps', 'locations.tsv')),
              col_sep: "\t").each_with_object({}) do |(home_location, library_code, folio_code), hash|
      # Skipping location codes that we want to handle as FOLIO codes in SearchWorks.
      next if LOCATIONS_TO_SKIP.include?(folio_code) || SYMPHONY_CODES_TO_SKIP.include?([library_code, home_location])

      # SAL3's CDL/ONORDER/INPROCESS locations are all mapped so SAL3-STACKS
      next if folio_code == 'SAL3-STACKS' && home_location != 'STACKS'

      # Recode SUL-SDR to have "INTERNET" be it's home_locaion
      home_location = 'INTERNET' if home_location == 'SDR'

      hash[folio_code] ||= [library_code, home_location]
    end
  end

  def load_current_locations
    CSV.parse(File.read(File.join(__dir__, 'translation_maps', 'temp_locations.tsv')),
              col_sep: "\t").each_with_object({}) do |(current_location, library_code, folio_code), hash|
      # Skipping location codes that we want to handle as FOLIO codes in SearchWorks.
      next if LOCATIONS_TO_SKIP.include?(folio_code)

      hash[folio_code] ||= [library_code, current_location]
    end
  end
end
