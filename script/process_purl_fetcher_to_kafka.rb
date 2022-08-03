require_relative '../config/boot'

require 'traject'
require 'traject/readers/purl_fetcher_reader'
require 'traject/extractors/purl_fetcher_kafka_extractor'

log_file = File.expand_path("../log/process_purl_fetcher_to_kafka_#{Utils.env_config.kafka_topic}.log", __dir__)
Utils.set_log_file(log_file)

state_file = ENV['STATE_FILE'] || File.expand_path("../tmp/searchworks_traject_indexer_last_run_#{Utils.env_config.kafka_topic}", __dir__)

File.open(state_file, 'w') { |f| f.puts Time.parse('1970-01-01T00:00:00Z') } unless File.exist? state_file

count = 0

File.open(state_file, 'r+') do |f|
  f.flock(File::LOCK_EX|File::LOCK_NB)

  last_date = Time.parse(f.read.strip)
  Utils.logger.info "Found last_date in #{state_file}: #{last_date}"

  reader = Traject::PurlFetcherReader.new(nil, 'purl_fetcher.first_modified': last_date.to_s, 'purl_fetcher.url': Utils.env_config.purl_fetcher_url)

  reader.each_slice(1000) do |batch|
    Traject::PurlFetcherKafkaExtractor.new(reader: batch, kafka: Utils.kafka, topic: Utils.env_config.kafka_topic).process!

    count += batch.length

    max_date = batch.map { |x, _| Time.parse(x['updated_at']) }.max
    Utils.logger.info "Found max_date: #{max_date} (previous: #{last_date})"
    if max_date > last_date
      f.rewind
      f.truncate(0)
      last_date = max_date
      f.puts(max_date)
      Utils.logger.info "Wrote new last date: #{max_date}"
    end
  end

  max_date = Time.parse(reader.range['last_modified']) if reader.range['last_modified']
  Utils.logger.info "Found max_date: #{max_date} (previous: #{last_date})"
  if max_date > last_date
    f.rewind
    f.truncate(0)
    last_date = max_date
    f.puts(max_date)
    Utils.logger.info "Wrote new last date: #{max_date}"
  end
end
