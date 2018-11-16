$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'traject'
require 'traject/extractors/purl_fetcher_kafka_extractor'

kafka = Kafka.new(ENV.fetch('KAFKA', 'localhost:9092').split(','))
state_file = File.expand_path('../tmp/searchworks_traject_indexer_last_run', __dir__)

File.open(state_file, 'w') { |f| f.puts Time.parse('1970-01-01T00:00:00') } unless File.exist? state_file

File.open(state_file, 'r+') do |f|
  f.flock(File::LOCK_EX)

  date = Time.now
  last_date = f.read.strip

  Traject::PurlFetcherKafkaExtractor.new(first_modified: last_date, kafka: kafka, topic: ENV['KAFKA_TOPIC']).process!

  f.rewind
  f.truncate(0)
  f.puts(date)
end

kafka.deliver_message(nil, key: 'break', topic: ENV['KAFKA_TOPIC'])
