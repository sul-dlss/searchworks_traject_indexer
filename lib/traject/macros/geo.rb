# frozen_string_literal: true

module Traject
  module Macros
    # Traject macros for working with geospatial data
    module Geo
      # Convert values into a hash with a given URI key
      # Used for the dct_references_s field:
      # https://opengeometadata.org/ogm-aardvark/#references
      def as_reference(uri)
        lambda do |_record, accumulator, _context|
          accumulator.map! { |reference| { uri => reference } }
        end
      end
    end
  end
end
