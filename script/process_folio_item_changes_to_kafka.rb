require_relative '../config/boot'

require 'folio_client'
require 'traject'
require 'traject/readers/folio_reader'
require 'traject/extractors/folio_kafka_extractor'


log_file = File.expand_path("../log/process_folio_item_changes__to_kafka_#{Utils.env_config.kafka_topic}.log", __dir__)
Utils.set_log_file(log_file)

state_file = ENV['STATE_FILE'] || File.expand_path(
  "../tmp/searchworks_traject_folio_item_changes_indexer_last_run_#{Utils.env_config.kafka_topic}", __dir__
)

# Make sure there's a valid last response date to parse from the state file
# TODO: default to the last full dump date
File.open(state_file, 'w') { |f| f.puts "2022-08-16T15:00:00Z" } unless File.exist? state_file

File.open(state_file, 'r+') do |f|
  f.flock(File::LOCK_EX | File::LOCK_NB)

  last_date = Time.iso8601(f.read.strip)
  Utils.logger.info "Found last_date in #{state_file}: #{last_date}"

  client = FolioClient.new(url: Utils.env_config.okapi_url || ENV['OKAPI_URL'])
  response = client.get('/item-storage/items', params: { query: "metadata.updatedDate >= #{last_date.utc.iso8601}", limit: 2147483647 })
  last_response_date = Time.httpdate(response.headers['Date'])

  items = JSON.parse(response.body.to_s)['items']

  source_records_for_changed_items = items.uniq { |item| item['holdingsRecordId'] }.lazy.map do |item|
    client.holdings_record(id: item['holdingsRecordId'])
  end.uniq { |holdings| holdings['instanceId'] }.map do |holdings|
    client.source_record(instanceId: holdings['instanceId'])
  end

  Traject::FolioKafkaExtractor.new(reader: source_records_for_changed_items, kafka: Utils.kafka, topic: Utils.env_config.kafka_topic).process!

  Utils.logger.info "Response generated at: #{last_response_date} (previous: #{last_date})"

  if last_response_date > last_date
    f.rewind
    f.truncate(0)
    f.puts(last_response_date.iso8601)
    Utils.logger.info "Wrote new last date: #{last_response_date}"
  end
end
