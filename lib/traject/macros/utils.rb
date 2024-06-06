# frozen_string_literal: true

module Traject
  module Macros
    module Utils
      def join(separator)
        lambda do |_record, accumulator, _context|
          accumulator.map! { |values| values.join(separator) if values.any? }.compact!
        end
      end

      def flatten
        lambda do |_record, accumulator, _context|
          accumulator.flatten! if accumulator.any?
        end
      end

      def sort(reverse: false)
        lambda do |_record, accumulator, _context|
          accumulator.sort!
          accumulator.reverse! if reverse
        end
      end

      def format_datetimes
        lambda do |_record, accumulator, _context|
          accumulator.map! { |dt| dt&.strftime('%Y-%m-%dT%H:%M:%SZ') }.compact!
        end
      end

      # Like #select, but calls the callable and provides the record and context too
      # Use to filter values based on another macro
      def filter(callable)
        lambda do |record, accumulator, context|
          accumulator.select! { |value| callable.call(record, value, context) }
        end
      end
    end
  end
end
