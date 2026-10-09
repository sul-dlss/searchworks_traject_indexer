# frozen_string_literal: true

require 'json'
require 'time'
require 'base64'
require 'zlib'

module StreamingIndexer
  # Publishes terminal failures to Kafka before their source offsets are
  # checkpointed. If quarantine itself is unavailable, it raises so the source
  # batch remains uncheckpointed and can be replayed.
  class QuarantineWriter
    def initialize(kafka:, topic:, retry_policy:, producer: nil)
      raise ArgumentError, 'quarantine topic is required' if topic.to_s.empty?

      @topic = topic
      @retry_policy = retry_policy
      @producer = producer || kafka.producer(required_acks: :all, max_retries: 0)
    end

    def write(failures)
      return if failures.empty?

      failures.each do |failure|
        @producer.produce(
          JSON.fast_generate(payload(failure)),
          key: quarantine_key(failure),
          topic: @topic
        )
      end
      @retry_policy.call(stage: :quarantine) { @producer.deliver_messages }
    end

    def close
      @producer.shutdown
    end

    private

    def payload(failure)
      event = failure.event
      {
        schema_version: 1,
        status: 'quarantined',
        source: event.source,
        source_topic: event.topic,
        source_partition: event.partition,
        source_offset: event.offset,
        source_key: event.key.to_s.scrub,
        source_value_encoding: 'gzip+base64',
        source_value_gzip_base64: encode(event.value),
        source_create_time: event.create_time&.iso8601,
        document_id: failure.id,
        stage: failure.stage,
        attempts: failure.attempts,
        error_class: failure.error.class.name,
        error_message: failure.error.message,
        error_status: failure.error.respond_to?(:status) ? failure.error.status : nil,
        error_body: failure.error.respond_to?(:body) ? failure.error.body.to_s.slice(0, 4000) : nil,
        quarantined_at: Time.now.utc.iso8601,
        indexer_version: Utils.version
      }
    end

    def quarantine_key(failure)
      event = failure.event
      [event.topic, event.partition, event.offset].join(':')
    end

    def encode(value)
      Base64.strict_encode64(Zlib.gzip(value.to_s))
    end
  end
end
