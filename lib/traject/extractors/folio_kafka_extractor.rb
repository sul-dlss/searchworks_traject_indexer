# frozen_string_literal: true

require 'kafka'
require 'kafka/statsd'

# Produces kafka messages with data read from Folio
class Traject::FolioKafkaExtractor
  attr_reader :reader, :kafka, :topic

  # @param [Traject::FolioPostgresReader,Traject::FolioReader] reader reads records from folio
  # @param [Kafka] kafka the connection to kafka
  # @param [String] topic the kafka topic
  def initialize(reader:, kafka:, topic:)
    @reader = reader
    @kafka = kafka
    @topic = topic
  end

  def process!
    i = 0
    reader.each do |record|
      Utils.logger.debug("Traject::FolioKafkaExtractor#each(#{record.instance_id})")

      # sometimes folio source records don't have an associated instance record
      next if record.instance_id.nil? || record.instance_id.empty?

      i += 1

      producer.produce(JSON.fast_generate(record.as_json), key: record.instance_id, topic:)
    end

    Kafka::Statsd.statsd.count("producer.ruby-kafka.#{topic}.produce.messages", 0, 1) if i.zero?

    i
  ensure
    producer.deliver_messages
    producer.shutdown
    @producer = nil
  end

  private

  def producer
    @producer ||= kafka.async_producer(
      # Trigger a delivery once 10 messages have been buffered.
      delivery_threshold: 100,

      # Trigger a delivery every 30 seconds.
      delivery_interval: 30,
      max_queue_size: 10_000_000,

      compression_codec: :gzip,
      max_retries: 5,
      retry_backoff: 5,
      max_buffer_bytesize: 100_000_000
    )
  end
end
