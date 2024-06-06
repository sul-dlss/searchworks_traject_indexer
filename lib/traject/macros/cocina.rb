# frozen_string_literal: true

module Traject
  module Macros
    module Cocina
      def druid
        lambda do |record, accumulator, _context|
          accumulator << record.druid
        end
      end

      def cocina_descriptive(*fields)
        lambda do |record, accumulator, _context|
          accumulator.concat(fields.reduce([record.cocina_description]) do |nodes, field|
            nodes.flat_map { |node| node.public_send(field) }.compact
          end)
        end
      end

      def cocina_structural(*fields)
        lambda do |record, accumulator, _context|
          accumulator.concat(fields.reduce([record.cocina_structural]) do |nodes, field|
            nodes.flat_map { |node| node.public_send(field) }.compact
          end)
        end
      end

      def cocina_access(*fields)
        lambda do |record, accumulator, _context|
          accumulator.concat(fields.reduce([record.cocina_access]) do |nodes, field|
            nodes.flat_map { |node| node.public_send(field) }.compact
          end)
        end
      end

      def cocina_titles(type: :main)
        lambda do |record, accumulator, _context|
          accumulator.concat record.cocina_titles(type:)
        end
      end

      def select_type(type)
        lambda do |_record, accumulator, _context|
          accumulator.map! { |node| node if node.type == type }.compact!
        end
      end

      def select_role(role)
        lambda do |_record, accumulator, _context|
          accumulator.map! { |node| node if node.role.find { |r| r.value == role } }.compact!
        end
      end

      def extract_dates
        lambda do |_record, accumulator, _context|
          accumulator.map!(&:date).flatten!.compact! if accumulator.any?
        end
      end

      def extract_values
        lambda do |_record, accumulator, _context|
          accumulator.map!(&:value).compact!
        end
      end

      def parse_dates
        lambda do |_record, accumulator, _context|
          accumulator.map! do |dt|
            Time.parse(dt)
          rescue ArgumentError
            nil
          end.compact!
        end
      end

      def extract_structured_values(flatten: false)
        lambda do |_record, accumulator, _context|
          accumulator.map! { |node| node.structuredValue.map(&:value) }
          accumulator.flatten! if flatten && accumulator.any?
          accumulator.compact!
        end
      end

      def extract_names
        lambda do |_record, accumulator, _context|
          accumulator.map! { |node| node.name.map(&:value) }.flatten!.compact! unless accumulator.empty?
        end
      end

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

      def sort
        lambda do |_record, accumulator, _context|
          accumulator.sort!
        end
      end
    end
  end
end
