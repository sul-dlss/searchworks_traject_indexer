# frozen_string_literal: true

require 'json'

module Traject
  class KafkaEmbeddingJobWriter
    def initialize(settings)
      @settings = settings
      @logger = settings['logger'] || Utils.logger
      @kafka = settings['embedding.kafka'] || settings['kafka.client']
      @topic = settings['embedding.kafka.topic']
      @source = settings['embedding.source']
      @retries = Integer(settings.fetch('embedding.kafka.retries', 5))
      @producer = settings['embedding.kafka.producer'] || build_producer
      @producer_mutex = Mutex.new
      @input_builder = EmbeddingInputBuilder.new(
        max_input_chars: settings.fetch('embedding.max_input_chars', EmbeddingInputBuilder::DEFAULT_MAX_INPUT_CHARS)
      )

      raise ArgumentError, 'embedding.kafka, kafka.client, or embedding.kafka.producer setting is required' unless @producer
      raise ArgumentError, 'embedding.kafka.topic setting is required' if @topic.to_s.empty?
      raise ArgumentError, 'embedding.source setting is required' if @source.to_s.empty?
    end

    def put(context)
      job = EmbeddingJob.from_context(
        context,
        source: @source,
        input_builder: @input_builder,
        schema_version: @settings.fetch('embedding.schema_version', EmbeddingJob::DEFAULT_SCHEMA_VERSION),
        model: @settings.fetch('embedding.model', EmbeddingJob::DEFAULT_MODEL),
        dimensions: @settings.fetch('embedding.dimensions', EmbeddingJob::DEFAULT_DIMENSIONS)
      )

      unless job
        @logger.warn("Not publishing embedding job without an id: #{context.record_inspect}")
        return
      end

      @producer_mutex.synchronize do
        @producer.produce(
          JSON.fast_generate(job.as_json),
          key: job.id,
          topic: @topic
        )
        @producer.deliver_messages
      end
    end

    # Existing Solr indexing treats skipped contexts with an ID as deletes.
    # Publish those contexts so the embedding index mirrors the Solr deletion.
    def write_skipped_records?
      true
    end

    def close
      @producer_mutex.synchronize { @producer.shutdown }
    end

    private

    def build_producer
      return unless @kafka

      @kafka.producer(
        required_acks: :all,
        ack_timeout: Integer(@settings.fetch('embedding.kafka.ack_timeout', 10)),
        max_retries: @retries,
        retry_backoff: Integer(@settings.fetch('embedding.kafka.retry_backoff', 5)),
        compression_codec: :gzip
      )
    end
  end
end
