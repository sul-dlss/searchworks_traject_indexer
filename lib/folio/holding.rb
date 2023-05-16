# frozen_string_literal: true

# This code may look unusually verbose for Ruby (and it is), but
# it performs some subtle and complex validation of JSON data.
#
# To parse this JSON, add 'dry-struct' and 'dry-types' gems, then do:
#
#   holding = Holding.from_json! "{…}"
#   puts holding.tags&.tag_list&.first
#
# If from_json! succeeds, the value returned matches the schema.

require 'json'
require 'dry-types'
require 'dry-struct'

module Folio
  module Holding
    module Types
      include Dry.Types(default: :nominal)

      Integer  = Strict::Integer
      Bool     = Strict::Bool
      Hash     = Strict::Hash
      String   = Strict::String
    end

    class HoldingsType < Dry::Struct
      # The identifier, a UUID
      attribute :id, Types::String

      attribute :name, Types::String

      attribute :source, Types::String

      def self.from_dynamic!(dyn)
        dyn = Types::Hash[dyn]
        new(id: dyn.fetch('id'),
            name: dyn.fetch('name'),
            source: dyn.fetch('source'))
      end
    end

    class HoldingsStatement < Dry::Struct
      # Note attached to a holdings statement
      attribute :note, Types::String.optional

      # Private note attached to a holdings statment
      attribute :staff_note, Types::String.optional

      # Specifices the exact content to which the library has access, typically for continuing
      # publications.
      attribute :statement, Types::String.optional

      def self.from_dynamic!(dyn)
        dyn = Types::Hash[dyn]
        new(
          note: dyn['note'],
          staff_note: dyn['staffNote'],
          statement: dyn['statement']
        )
      end

      def self.from_json!(json)
        from_dynamic!(JSON.parse(json))
      end
    end

    # A holdings record
    class Holding < Dry::Struct
      # Notes about action, copy, binding etc.
      attribute :holdings_statements, Types.Array(HoldingsStatement)

      # Holdings record indexes statements
      attribute :holdings_statements_for_indexes, Types.Array(HoldingsStatement)

      # Holdings record supplements statements
      attribute :holdings_statements_for_supplements, Types.Array(HoldingsStatement)

      # The description of the holding type
      attribute :holdings_type, HoldingsType

      # the unique ID of the holdings record; UUID
      attribute :id, Types::String

      attribute :discovery_suppress, Types::Bool

      # The effective shelving location in which an item resides
      attribute :effective_location, Types::Hash.meta(of: Types::Any).optional

      def self.from_dynamic!(dyn)
        d = Types::Hash[dyn]
        new(
          holdings_statements: d.fetch('holdingsStatements').map { |x| HoldingsStatement.from_dynamic!(x) },
          holdings_statements_for_indexes: d.fetch('holdingsStatementsForIndexes').map { |x| HoldingsStatement.from_dynamic!(x) },
          holdings_statements_for_supplements: d.fetch('holdingsStatementsForSupplements').map { |x| HoldingsStatement.from_dynamic!(x) },
          holdings_type: HoldingsType.from_dynamic!(d['holdingsType']),
          id: d.fetch('id'),
          discovery_suppress: d.fetch('suppressFromDiscovery'),
          effective_location: Types::Hash.optional[d.dig('location', 'effectiveLocation')]&.transform_values { |v| Types::Any[v] }
        )
      end

      def self.from_json!(json)
        from_dynamic!(JSON.parse(json))
      end
    end
  end
end
