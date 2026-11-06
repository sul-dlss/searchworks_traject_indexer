# frozen_string_literal: true

require 'digest/sha2'

module StreamingIndexer
  # Adds a cached or newly generated vector to a complete mapped document.
  # The regular Solr sink subsequently writes that complete document, so no
  # partial or atomic Solr update is involved.
  class EmbeddingEnricher
    DEFAULT_SCHEMA_VERSION = 'searchworks-bib-v1'
    DEFAULT_MODEL = 'gemini-embedding-2'
    DEFAULT_DIMENSIONS = 768

    Result = Data.define(:succeeded, :failed)

    class Null
      def enrich(operations)
        Result.new(succeeded: operations, failed: [])
      end
    end

    def initialize(settings, client:, cache:, retry_policy:, metrics: nil, logger: Utils.logger) # rubocop:disable Metrics/ParameterLists
      @settings = Traject::Indexer::Settings.new(settings)
      @client = client
      @cache = cache
      @retry_policy = retry_policy
      @metrics = metrics || Metrics::Null.new
      @logger = logger
      @batch_size = [Integer(@settings.fetch('embedding.batch_size', 100)), 1].max
      @input_builder = EmbeddingInputBuilder.new(
        max_input_chars: @settings.fetch('embedding.max_input_chars', EmbeddingInputBuilder::DEFAULT_MAX_INPUT_CHARS)
      )
    end

    def enrich(operations)
      deletes, adds = operations.partition(&:delete?)
      succeeded = deletes.dup
      failed = []

      adds.each_slice(@batch_size) do |batch|
        succeeded.concat(enrich_with_retries(batch))
      rescue StandardError => e
        isolate(batch, succeeded:, failed:, batch_error: e)
      end

      Result.new(succeeded:, failed:)
    end

    private

    attr_reader :settings, :client, :cache, :retry_policy, :metrics, :logger

    def isolate(batch, succeeded:, failed:, batch_error:)
      if batch.one?
        failed << failure(batch.first, batch_error)
        return
      end

      batch.each do |operation|
        succeeded.concat(enrich_with_retries([operation]))
      rescue StandardError => e
        failed << failure(operation, e)
      end
    end

    def enrich_with_retries(operations)
      jobs = operations.map { |operation| job_for(operation) }
      cached = retry_policy.call(
        stage: :embedding_cache,
        retry_if: ->(error) { error.is_a?(SolrEmbeddingCache::RetryableError) }
      ) { cache.vectors_for(jobs) }
      missing = jobs.reject { |job| cached.key?(job.fetch('id')) }
      vectors = embed(missing)

      metrics.embedding_cache_hit(count: cached.length)
      metrics.embedding_cache_miss(count: missing.length)
      operations.zip(jobs).map do |operation, job|
        vector = cached[job.fetch('id')] || vectors.fetch(job.fetch('id'))
        enriched(operation, job, vector)
      end
    end

    def embed(jobs)
      return {} if jobs.empty?

      vectors = retry_policy.call(
        stage: :embedding_gateway,
        retry_if: ->(error) { error.is_a?(EmbeddingClient::RetryableError) }
      ) do
        client.embed(
          inputs: jobs.map { |job| job.fetch('input') },
          model: jobs.first.fetch('model'),
          dimensions: jobs.first.fetch('dimensions')
        )
      end
      jobs.zip(vectors).to_h { |job, vector| [job.fetch('id'), vector] }
    end

    def job_for(operation)
      input = @input_builder.build(operation.document)
      {
        'id' => operation.id.to_s,
        'input' => input,
        'input_hash' => "sha256:#{Digest::SHA256.hexdigest(input)}",
        'schema_version' => settings.fetch('embedding.schema_version', DEFAULT_SCHEMA_VERSION).to_s,
        'model' => settings.fetch('embedding.model', DEFAULT_MODEL).to_s,
        'dimensions' => Integer(settings.fetch('embedding.dimensions', DEFAULT_DIMENSIONS)),
        'source' => operation.event.source.to_s
      }
    end

    def enriched(operation, job, vector)
      document = operation.document.merge(
        'embedding_vector' => vector,
        'embedding_input_hash_ss' => job.fetch('input_hash'),
        'embedding_model_ss' => job.fetch('model'),
        'embedding_schema_version_ssi' => job.fetch('schema_version'),
        'embedding_source_ss' => job.fetch('source'),
        'embedding_dimensions_is' => job.fetch('dimensions')
      )
      metrics.embedding_processed(count: 1)
      Operation.add(id: operation.id, document:, event: operation.event)
    end

    def failure(operation, error)
      Failure.new(
        event: operation.event,
        stage: :embedding,
        error:,
        id: operation.id,
        attempts: retry_policy.max_attempts
      )
    end
  end
end
