$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'traject'
require 'traject/extractors/marc_kafka_extractor'
require 'traject/readers/marc_combining_reader'
require "logger"
kafka = Kafka.new(ENV.fetch('KAFKA', 'localhost:9092').split(','))

ARGV.each do |path|
  File.open(path, 'r') do |f|
    f.flock(File::LOCK_EX)

    if path =~ /\.del$/
      producer = kafka.async_producer(
          # Trigger a delivery once 100 messages have been buffered.
          delivery_threshold: 100,

          # Trigger a delivery every 30 seconds.
          delivery_interval: 30,
          max_queue_size: 10000000
        )

      f.each_line do |ckey|
        producer.produce(nil, key: ckey.strip, topic: ENV['KAFKA_TOPIC'])
      end

      producer.deliver_messages
      producer.shutdown
    else
      reader = Traject::MarcCombiningReader.new(f, 'marc_source.type' => 'binary', 'marc4j_reader.permissive' => true)
      Traject::MarcKafkaExtractor.new(reader: reader, kafka: kafka, topic: ENV['KAFKA_TOPIC']).process!
    end

    File.delete(f)
  end
end

kafka.deliver_message(nil, key: 'break', topic: ENV['KAFKA_TOPIC'])
