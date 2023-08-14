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
      library_code = { 'LANE' => 'LANE-MED' }.fetch(library_code, library_code)

      # Skipping location codes that we want handle as FOLIO codes in SearchWorks.
      next if LOCATIONS_TO_SKIP.include?(folio_code)

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
      # Skipping location codes that we want handle as FOLIO codes in SearchWorks.
      next if LOCATIONS_TO_SKIP.include?(folio_code)

      hash[folio_code] ||= [library_code, current_location]
    end
  end
end
