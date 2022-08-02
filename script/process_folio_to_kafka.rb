$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'utils'
require 'logger'

require 'folio_client'
require 'traject'
require 'traject/readers/folio_reader'
require 'traject/extractors/folio_kafka_extractor'

log_file = File.expand_path("../log/process_folio_to_kafka_#{ENV['KAFKA_TOPIC']}.log", __dir__)
Utils.logger = Logger.new(log_file)
kafka = Kafka.new(ENV.fetch('KAFKA', 'localhost:9092').split(','), logger: Utils.logger)
state_file = ENV['STATE_FILE'] || File.expand_path(
  "../tmp/searchworks_traject_folio_indexer_last_run_#{ENV['KAFKA_TOPIC']}", __dir__
)

# Make sure there's a valid last response date to parse from the state file
File.open(state_file, 'w') { |f| f.puts '1970-01-01T00:00:00Z' } unless File.exist? state_file

File.open(state_file, 'r+') do |f|
  f.flock(File::LOCK_EX | File::LOCK_NB)

  last_date = Time.iso8601(f.read.strip)
  Utils.logger.info "Found last_date in #{state_file}: #{last_date}"

  reader = Traject::FolioReader.new(nil, 'folio.updated_after': last_date.utc.iso8601, 'folio.client': FolioClient.new(url: ENV['OKAPI_URL'], username: ENV['OKAPI_USER'], password: ENV['OKAPI_PASSWORD']))

  Traject::FolioKafkaExtractor.new(reader: reader, kafka: kafka, topic: ENV['KAFKA_TOPIC']).process!

  Utils.logger.info "Response generated at: #{reader.last_response_date} (previous: #{last_date})"

  if reader.last_response_date > last_date
    f.rewind
    f.truncate(0)
    f.puts(reader.last_response_date.iso8601)
    Utils.logger.info "Wrote new last date: #{reader.last_response_date}"
  end
end
