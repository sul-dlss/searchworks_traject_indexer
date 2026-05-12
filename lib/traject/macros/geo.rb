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

      # Determine if an object is georeferenced
      # Used for the gbl_georeferenced_b field:
      # https://opengeometadata.org/ogm-aardvark/#georeferenced
      def georeferenced?
        lambda do |record, accumulator, _context|
          # All vector data types are georeferenced by definition
          return accumulator.replace([true]) if record.files(filename: /\.(geojson|shp|fgb)$/).any?

          # For raster data, check for geotiff/COG MIME type or presence of a world file
          return accumulator.replace([true]) if record.files(mime_type: /application=geotiff/).any?
          return accumulator.replace([true]) if record.files(filename: /\.tfw$/).any?

          # For a IIIF image/map, check for the presence of georeference annotations
          return accumulator.replace([true]) if record.files(filename: /\.json$/, use: 'annotations').any?

          accumulator.replace([false])
        end
      end
    end
  end
end
