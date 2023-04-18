# frozen_string_literal: true

require 'kafka'
require 'kafka/statsd'
require 'active_support' # required internally by ruby-kafka

class Traject::MarcKafkaExtractor
  attr_reader :reader, :kafka, :topic

  def initialize(reader:, kafka:, topic:)
    @reader = reader
    @kafka = kafka
    @topic = topic
  end

  def process!
    reader.combinable_records do |records_to_combine|
      ckey = records_to_combine.first['001'].value.sub(/^a/, '')
      Utils.logger.debug("Traject::MarcKafkaExtractor#each(#{ckey})")

      producer.produce(records_to_combine.map { |x| x.to_marc }.join(''), key: ckey, topic:)
    end
  ensure
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
      max_queue_size: 10_000_000
    )
  end
end
