$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'utils'
require 'logger'

require 'traject'
require 'traject/extractors/crez_marc_kafka_extractor'

log_file = File.expand_path("../log/process_crez_marc_to_kafka_#{ENV['KAFKA_TOPIC']}", __dir__)
Utils.logger = Logger.new(log_file)
kafka = Kafka.new(ENV.fetch('KAFKA', 'localhost:9092').split(','), logger: Utils.logger)

ARGV.each do |path|
  Traject::CrezMarcKafkaExtractor.new(reserves_file: path, kafka: kafka, topic: ENV['KAFKA_TOPIC']).process!
end
