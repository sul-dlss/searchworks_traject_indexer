# frozen_string_literal: true

module Traject
  module Macros
    # Generic traject macros inspired by enumerable methods
    module Extras
      # Join values in the accumulator with a separator
      def join(separator)
        lambda do |_record, accumulator, _context|
          accumulator.map! { |values| values.join(separator) if values.any? }.compact!
        end
      end

      # Flatten nested arrays
      def flatten
        lambda do |_record, accumulator, _context|
          accumulator.flatten! if accumulator.any?
        end
      end

      # Sort the accumulator in ascending or descending order
      # NOTE: reversing after sorting is more efficient than sorting in reverse
      def sort(reverse: false)
        lambda do |_record, accumulator, _context|
          accumulator.sort!
          accumulator.reverse! if reverse
        end
      end

      # Convert Time objects into solr-format strings
      def format_datetimes
        lambda do |_record, accumulator, _context|
          accumulator.map! { |dt| dt&.strftime('%Y-%m-%dT%H:%M:%SZ') }.compact!
        end
      end

      # Replace the accumulator with its min and max values
      def minmax
        lambda do |_record, accumulator, _context|
          accumulator.replace [accumulator.minmax] if accumulator.any?
        end
      end

      # Add the value(s) of a field that has already been processed to the accumulator
      def use_field(field)
        lambda do |_record, accumulator, context|
          accumulator.concat Array.wrap(context.output_hash[field]) if context.output_hash[field].present?
        end
      end

      # Given a list of years, return a list with the unique centuries and decades covered by those years, and prefixes on the
      # decade and year strings for easy parsing of century and decade when using the Solr results for hierarchical facet display.
      # E.g.,
      # * given: [1701, 1980, 1991, 1995]
      # * return: ["1700-1799", "1900-1999",
      #            "1700-1799:1700-1710", "1900-1999:1980-1989", "1900-1999:1990-1999",
      #            "1700-1799:1700-1710:1701", "1900-1999:1980-1989:1980", "1900-1999:1990-1999:1991", "1900-1999:1990-1999:1995"]
      # The standalone century and decade ranges make those ranges facetable/searchable, and including the ranges on the year strings
      # themselves makes it faster for consumers to parse out century/decade info, without duplicating the logic defined in this module.
      def hierarchicalize_year_list
        # @param accumulator [Array<Integer>] an array of strings or ints representing calendar years
        # @return [Array<String>] a list of strings with exploded century and decade info per the above description
        lambda do |_record, accumulator, _context|
          centuries = Set.new
          decades = Set.new
          hierarchicalized_years = accumulator.map do |year|
            century, decade = Utils.centimate_and_decimate(year)
            centuries << century
            decades << [century, decade].join(':')
            [century, decade, year].join(':')
          end
          accumulator.replace(centuries.to_a + decades.to_a + hierarchicalized_years)
        end
      end

      # Similar to Traject's built-in `literal` macro,
      # but allows for multiple values to be added to the accumulator.
      #
      # Usage:
      #   to_field 'sample', literal_multiple('Image', 'Image|Slide')
      def literal_multiple(*values)
        lambda do |_record, accumulator, _context|
          values.each { |value| accumulator << value }
        end
      end
    end
  end
end
