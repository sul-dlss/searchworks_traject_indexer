require 'kafka'
require 'kafka/statsd'
require 'manticore' if defined? JRUBY_VERSION

class Traject::PurlFetcherKafkaExtractor
  attr_reader :reader, :kafka, :topic

  def initialize(reader:, kafka:, topic:)
    @reader = reader
    @kafka = kafka
    @topic = topic
  end

  def process!
    reader.each do |change, meta|
      Utils.logger.debug("Traject::PurlFetcherKafkaExtractor#each(#{change['druid']})")
      if change[:delete]
        producer.produce(nil, key: change['druid'], topic: topic)
      else
        producer.produce(change.to_json, key: change['druid'], topic: topic)
      end
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
