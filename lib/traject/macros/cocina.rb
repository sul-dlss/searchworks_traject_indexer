# frozen_string_literal: true

module Traject
  module Macros
    # Traject macros for working with data from Cocina models
    module Cocina
      # Add the druid to the accumulator
      def druid
        lambda do |record, accumulator, _context|
          accumulator << record.druid
        end
      end

      # Add the top-level modified timestamp to the accumulator
      def modified
        lambda do |record, accumulator, _context|
          accumulator << record.modified
        end
      end

      # Add the top-level created timestamp to the accumulator
      def created
        lambda do |record, accumulator, _context|
          accumulator << record.created
        end
      end

      # Generate a url to the configured purl environment with the object's druid
      def purl_url
        lambda do |record, accumulator, _context|
          accumulator << "#{settings['purl.url']}/#{record.druid}"
        end
      end

      # Generate an embed url for the object, with optional parameters
      def embed_url(params = {})
        lambda do |record, accumulator, context|
          return if record.content_type == 'collection'

          params[:url] = purl_url.call(record, [], context).first
          accumulator << "#{settings['purl.url']}/embed.json?#{params.to_query}"
        end
      end

      # Generate a stacks download URL for the entire object (.zip)
      def stacks_object_url
        lambda do |record, accumulator, _context|
          return if record.content_type == 'collection'

          accumulator << "#{settings['stacks.url']}/object/#{record.druid}"
        end
      end

      # Generate a stacks download URL for each file, when the accumulator is an array of files
      def stacks_file_url
        lambda do |record, accumulator, _context|
          accumulator.map! do |file|
            "#{settings['stacks.url']}/file/druid:#{record.druid}/#{file['filename']}"
          end
        end
      end

      # Generate a IIIF manifest URL for the object via purl
      def iiif_manifest_url(version: 3)
        lambda do |record, accumulator, _context|
          return unless %w[image map book].include? record.content_type

          accumulator << if version == 3
                           "#{settings['purl.url']}/#{record.druid}/iiif3/manifest"
                         else
                           "#{settings['purl.url']}/#{record.druid}/iiif/manifest"
                         end
        end
      end

      # Traverse nested fields in the cocina descriptive metadata and return the result
      # Example: cocina_descriptive('geographic', 'form')
      def cocina_descriptive(*fields)
        lambda do |record, accumulator, _context|
          accumulator.concat(fields.reduce([record.cocina_description]) do |nodes, field|
            nodes.flat_map { |node| node[field] if node }.compact
          end)
        end
      end

      # Traverse nested fields in the cocina structural metadata and return the result
      def cocina_structural(*fields)
        lambda do |record, accumulator, _context|
          accumulator.concat(fields.reduce([record.cocina_structural]) do |nodes, field|
            nodes.flat_map { |node| node[field] if node }.compact
          end)
        end
      end

      # Traverse nested fields in the cocina access metadata and return the result
      def cocina_access(*fields)
        lambda do |record, accumulator, _context|
          accumulator.concat(fields.reduce([record.cocina_access]) do |nodes, field|
            nodes.flat_map { |node| node[field] if node }.compact
          end)
        end
      end

      # Add a Cocina::Models::TitleBuilder object to the accumulator
      # See PublicCocinaRecord#cocina_titles
      def cocina_titles(type: :main)
        lambda do |record, accumulator, _context|
          accumulator.concat record.cocina_titles(type:)
        end
      end

      # Filter nodes in the accumulator by type
      def select_type(type)
        lambda do |_record, accumulator, _context|
          accumulator.map! { |node| node if node['type'] == type }.compact!
        end
      end

      # Filter nodes in the accumulator by role value
      # Used when the accumulator is e.g. an array of contributor nodes
      def select_role(role)
        lambda do |_record, accumulator, _context|
          accumulator.map! { |node| node if node.fetch('role', []).find { |r| r['value'] == role } }.compact!
        end
      end

      # Get the value of the 'date' attribute from each node in the accumulator
      def extract_dates
        lambda do |_record, accumulator, _context|
          accumulator.map! { |node| node['date'] }.flatten!.compact! if accumulator.any?
        end
      end

      # Get the value of the 'value' attribute from each node in the accumulator
      def extract_values
        lambda do |_record, accumulator, _context|
          accumulator.map! { |node| node['value'] }.compact!
        end
      end

      # Return all parseable dates in the accumulator as Time objects
      def parse_dates
        lambda do |_record, accumulator, _context|
          accumulator.map! do |dt|
            Time.parse(dt)
          rescue ArgumentError
            nil
          end.compact!
        end
      end

      # Get all of the four-digit years from the accumulator
      def extract_years
        lambda do |_record, accumulator, _context|
          accumulator.select! { |date| date.match?(/^\d{1,4}([–-]\d{1,4})?$/) }
          accumulator.map! { |date| date.split(/[–-]/) }
          accumulator.flatten!
          accumulator.map!(&:to_i)
        end
      end

      # Pull out all structured values from the accumulator
      def extract_structured_values(flatten: false)
        lambda do |_record, accumulator, _context|
          accumulator.map! { |node| node.fetch('structuredValue', []).map { |n| n['value'] } }
          accumulator.flatten! if flatten && accumulator.any?
          accumulator.compact!
        end
      end

      # Pull out all names from the accumulator
      # Used when the accumulator is e.g. an array of contributor nodes
      def extract_names
        lambda do |_record, accumulator, _context|
          accumulator.map! { |node| node.fetch('name', []).map { |n| n['value'] } }.flatten!.compact! unless accumulator.empty?
        end
      end

      # Get all files from cocina structural whose filename matches the pattern
      # Filters the accumulator if it is not empty; otherwise search all files
      def select_files(pattern)
        lambda do |record, accumulator, _context|
          accumulator.concat record.files if accumulator.empty?
          accumulator.select! { |file| file['filename'].match?(pattern) }
        end
      end

      # Find the first file in cocina structural whose filename matches the pattern
      # Filters the accumulator if it is not empty; otherwise search all files
      def find_file(pattern)
        lambda do |record, accumulator, context|
          select_files(pattern).call(record, accumulator, context)
          accumulator.replace(accumulator.first(1))
        end
      end
    end
  end
end
