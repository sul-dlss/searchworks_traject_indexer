# frozen_string_literal: true

require 'csv'

# This starts with the location.tsv file provided by libsys. We make any modifications to that data here.
class LocationsMap
  include Singleton

  # @return a tuple of library code and location code
  def self.for(key)
    instance.data[key]
  end

  def data
    @data ||= load_map
  end

  def load_map
    CSV.parse(File.read(File.join(__dir__, 'translation_maps', 'locations.tsv')),
              col_sep: "\t").each_with_object({}) do |(home_location, library_code, folio_code), hash|
      library_code = { 'LANE' => 'LANE-MED' }.fetch(library_code, library_code)

      # SAL3's CDL/ONORDER/INPROCESS locations are all mapped so SAL3-STACKS
      next if folio_code == 'SAL3-STACKS' && home_location != 'STACKS'

      # Recode SUL-SDR to have "INTERNET" be it's home_locaion
      home_location = 'INTERNET' if home_location == 'SDR'

      hash[folio_code] ||= [library_code, home_location]
    end
  end
end
