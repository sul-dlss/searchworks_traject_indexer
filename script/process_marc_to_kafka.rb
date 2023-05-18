# frozen_string_literal: true

require_relative '../config/boot'

log_file = File.expand_path("../log/process_marc_to_kafka_#{Utils.env_config.kafka_topic}.log", __dir__)
Utils.set_log_file(log_file)

ARGV.each do |path|
  File.open(path, 'r') do |f|
    f.flock(File::LOCK_EX)

    if path =~ /\.del$/
      producer = Utils.kafka.async_producer(
        # Trigger a delivery once 100 messages have been buffered.
        delivery_threshold: 100,

        # Trigger a delivery every 30 seconds.
        delivery_interval: 30,
        max_queue_size: 10_000_000
      )

      f.each_line do |ckey|
        producer.produce(nil, key: ckey.strip, topic: Utils.env_config.kafka_topic)
      end

      producer.deliver_messages
      producer.shutdown
    else
      reader = Traject::MarcCombiningReader.new(f, 'marc_source.type' => 'binary', 'marc4j_reader.permissive' => true)
      Traject::MarcKafkaExtractor.new(reader:, kafka: Utils.kafka, topic: Utils.env_config.kafka_topic).process!
    end

    File.delete(f)
  end
end
