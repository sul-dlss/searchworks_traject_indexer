require 'kafka'
require 'kafka/statsd'

class Traject::FolioKafkaExtractor
  attr_reader :reader, :kafka, :topic

  def initialize(reader:, kafka:, topic:)
    @reader = reader
    @kafka = kafka
    @topic = topic
  end

  def process!
    reader.each do |record|
      Utils.logger.debug("Traject::FolioKafkaExtractor#each(#{record.instance_id})")
      producer.produce(record.record.to_json, key: record.instance_id, topic: topic)
    end

    producer.deliver_messages
    producer.shutdown
    @producer = nil
  end

  private

  def producer
    @producer ||= kafka.async_producer(
      # Trigger a delivery once 10 messages have been buffered.
      delivery_threshold: 10,

      # Trigger a delivery every 30 seconds.
      delivery_interval: 30,
      max_queue_size: 10000000
    )
  end
end