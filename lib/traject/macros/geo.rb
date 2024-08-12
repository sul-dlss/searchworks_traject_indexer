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

      # Generate a solr-formatted ENVELOPE string from a degree/minute/second-format string
      # Expects a cocina descriptive value with a single string
      def format_envelope_dms
        lambda do |_record, accumulator, _context|
          accumulator.map! do |subject|
            coordinates = Stanford::Geo::Coordinate.parse(subject['value'])
            coordinates.as_envelope if coordinates.valid?
          end.compact!
        end
      end

      # Generate a solr-formatted ENVELOPE string from a bounding box
      # Expects a cocina structuredValue with four elements: west, east, north, south
      def format_envelope_bbox
        lambda do |_record, accumulator, _context|
          accumulator.map! do |subject|
            structured_values = subject['structuredValue'] || []
            west = structured_values.find { |val| val['type'] == 'west' }
            east = structured_values.find { |val| val['type'] == 'east' }
            north = structured_values.find { |val| val['type'] == 'north' }
            south = structured_values.find { |val| val['type'] == 'south' }
            coordinates = Stanford::Geo::Coordinate.new(
              min_x: west['value'],
              min_y: south['value'],
              max_x: east['value'],
              max_y: north['value']
            )
            coordinates.as_envelope if coordinates.valid?
          end.compact!
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

      # Assigns "map" or "dataset" to the accumulator based on the presence of those substrings
      # For example, "Digital Map" "Digital Maps" and "Maps and Atlases" will be assigned "map"
      # "Dataset#Raster" will be assigned "dataset"
      # We do not want to remove the original values, so we append our value
      # (Original values, in addition to these appended values, are used by the translation_map for resource class)
      def assign_resource_class_values
        lambda do |_record, accumulator, _context|
          resource_classes = %w[dataset map]

          accumulator.map! do |value|
            # Find a matching substring, or return nil if none found
            matching_substring = resource_classes.find { |substr| value.downcase.include?(substr) }

            if matching_substring
              [matching_substring, value]
            else
              value
            end
          end if accumulator.any?

          # Remove nesting, duplicates
          accumulator.flatten! if accumulator.any?
          accumulator.uniq! if accumulator.any?
        end
      end

      private

      # Get the right geoserver url for an item given its access rights
      def geoserver_url(record)
        record.public_cocina.public? ? settings['geoserver.pub_url'] : settings['geoserver.stan_url']
      end
    end
  end
end
