# frozen_string_literal: true

require 'digest/sha2'

# Builds the message published to the compacted embedding-job Kafka topic.
#
# Upsert jobs contain a canonical text representation of the Solr document and
# the model settings needed by the downstream embedding worker. The input hash
# lets that worker detect unchanged content without generating another vector,
# while the schema version allows the message format or field selection to
# evolve explicitly.
#
# Delete jobs intentionally contain no embedding input. They tell downstream
# consumers to remove the document's vector when Traject skips a record that
# represents a deletion from Solr.
class EmbeddingJob
  DEFAULT_SCHEMA_VERSION = 'searchworks-bib-v1'
  DEFAULT_MODEL = 'gemini-embedding-2'
  DEFAULT_DIMENSIONS = 768

  attr_reader :id

  def self.from_context(context, **)
    id = Array(context.output_hash['id']).first
    return unless id

    new(id:, delete: context.skip?, document: context.output_hash, **)
  end

  def initialize(id:, source:, **options)
    @id = id.to_s
    @source = source
    @delete = options.fetch(:delete, false)
    @document = options.fetch(:document, {})
    @input_builder = options.fetch(:input_builder, EmbeddingInputBuilder.new)
    @schema_version = options.fetch(:schema_version, DEFAULT_SCHEMA_VERSION)
    @model = options.fetch(:model, DEFAULT_MODEL)
    @dimensions = Integer(options.fetch(:dimensions, DEFAULT_DIMENSIONS))
  end

  def as_json
    return delete_json if @delete

    input = @input_builder.build(@document)
    {
      id:,
      operation: 'upsert',
      input:,
      input_hash: "sha256:#{Digest::SHA256.hexdigest(input)}",
      schema_version: @schema_version,
      source: @source,
      model: @model,
      dimensions: @dimensions
    }
  end

  private

  def delete_json
    {
      id:,
      operation: 'delete',
      schema_version: @schema_version,
      source: @source
    }
  end
end
