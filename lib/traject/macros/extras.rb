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

      # Add the value of a field that has already been processed to the accumulator
      def use_field(field)
        lambda do |_record, accumulator, context|
          accumulator << context.output_hash[field] if context.output_hash[field].present?
        end
      end
    end
  end
end
