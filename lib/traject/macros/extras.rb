# frozen_string_literal: true

module Traject
  module Macros
    # Generic traject macros inspired by enumerable methods
    module Extras
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
    end
  end
end
