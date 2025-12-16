# frozen_string_literal: true

module Traject
  module Macros
    # Traject macros for working with data from Cocina models
    module Cocina
      # Call a method on the record and add result(s) to the accumulator
      def cocina_display(method_name, *args, **kwargs)
        lambda do |record, accumulator, _context|
          accumulator.concat Array(record.public_cocina.public_send(method_name, *args, **kwargs))
        end
      end

      # Map accumulator of files to their stacks download URLs
      def stacks_file_url
        lambda do |record, accumulator, _context|
          accumulator.map! do |file|
            "#{settings['stacks.url']}/file/druid:#{record.druid}/#{file['filename']}"
          end
        end
      end

      # Generate a Searchworks URL if object is released to Searchworks
      def searchworks_url
        lambda do |record, accumulator, _context|
          accumulator << record.searchworks_url if record.public_meta_json? && record.released_to_searchworks?
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
