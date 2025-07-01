# frozen_string_literal: true

module Traject
  module Macros
    module FolioFormat
      # Combine conditions with an action lambda
      # Returns a method that calls the action only if all conditions pass
      #
      # Usage:
      #   to_field 'sample', all_conditions(cond1, cond2, action_lambda)
      #
      # where cond = ->(rec, ctx) { true/false }
      # and action_lambda = ->(rec, acc, ctx) { acc << 'value' }
      def all_conditions(*args)
        *conditions, action = args

        lambda do |record, accumulator, context|
          action.call(record, accumulator, context) if conditions.all? { |condition| condition.call(record, context) }
        end
      end

      # Condition + action for a single condition only
      #
      # Usage:
      #   to_field 'sample', conditional(condition, action_lambda)
      #
      # where cond = ->(rec, ctx) { true/false }
      # and action_lambda = ->(rec, acc, ctx) { acc << 'value' }
      def condition(condition, action)
        lambda do |record, accumulator, context|
          action.call(record, accumulator, context) if condition.call(record, context)
        end
      end

      # Check if the MARC leader byte matches any of the specified values
      #
      # Usage:
      #   leader?(byte: 6, values: ['p', 't', 'd'])
      #   leader?(byte: 6, value: 'p')
      def leader?(byte:, values: nil, value: nil)
        raise ArgumentError, "Either 'values' or 'value' must be provided" if values.nil? && value.nil?

        values = Array(values) + Array(value)
        lambda do |record, _context|
          leader = record.leader
          return false unless leader && leader.length > byte

          values.include?(leader[byte])
        end
      end

      # Check a MARC subfield (like '245$h') for values that contain any of the specified strings
      #
      # Usage:
      #   marc_subfield_contains?('245', subfield: 'h', values: ['manuscript', 'manuscript/digital'])
      #   marc_subfield_contains?('245', subfield: 'h', value: 'manuscript')
      def marc_subfield_contains?(tag, subfield:, values: nil, value: nil)
        raise ArgumentError, "Either 'values' or 'value' must be provided" if values.nil? && value.nil?

        values = Array(values) + Array(value)

        lambda do |record, _context|
          record.fields(tag).any? do |field|
            field.subfields.any? do |sf|
              next unless sf.code == subfield

              field_value = sf.value.downcase

              values.any? do |v|
                if v.is_a?(Regexp)
                  field_value.match?(v)
                else
                  field_value.include?(v.downcase)
                end
              end
            end
          end
        end
      end

      # Check a control field (like '008') at a specific byte for matching values
      #
      # Usage:
      #   control_field_byte('008', byte: 26, values: ['a', 'b', 'c'])
      #   control_field_byte('008', byte: 26, value: 'a')
      def control_field_byte?(tag, byte:, values: nil, value: nil)
        raise ArgumentError, "Either 'values' or 'value' must be provided" if values.nil? && value.nil?

        values = Array(values) + Array(value)

        lambda do |record, _context|
          record.fields(tag).any? do |field|
            field_value = field.value
            next false unless field_value && field_value.length > byte

            character = field_value[byte]
            values.any? do |v|
              v.is_a?(Regexp) ? character.match?(v) : character == v
            end
          end
        end
      end
    end
  end
end
