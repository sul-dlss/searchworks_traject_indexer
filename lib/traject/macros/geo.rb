# frozen_string_literal: true

module Traject
  module Macros
    # Traject macros for working with geospatial data
    module Geo
      # Web Map Service, used for previewing and downloading geospatial data
      def wms_url
        lambda do |record, accumulator, _context|
          accumulator << "#{geoserver_url(record)}/wms" if record.content_type == 'geo'
        end
      end

      # Web Feature Service, used for inspecting features of vector data
      def wfs_url
        lambda do |record, accumulator, context|
          accumulator << "#{geoserver_url(record)}/wfs" if %w[GeoJSON Shapefile].intersect? context.output_hash['dct_format_s'].to_a
        end
      end

      # Web Coverage Service, used for retrieving raster data
      def wcs_url
        lambda do |record, accumulator, context|
          accumulator << "#{geoserver_url(record)}/wcs" if %w[GeoTIFF ArcGRID].intersect? context.output_hash['dct_format_s'].to_a
        end
      end

      # Convert values into a hash with a given URI key
      # Used for the dct_references_s field:
      # https://opengeometadata.org/ogm-aardvark/#references
      def as_reference(uri)
        lambda do |_record, accumulator, _context|
          accumulator.map! { |reference| { uri => reference } }
        end
      end

      private

      # Get the right geoserver url for an item given its access rights
      def geoserver_url(record)
        record.world_access? ? settings['geoserver.pub_url'] : settings['geoserver.stan_url']
      end
    end
  end
end
