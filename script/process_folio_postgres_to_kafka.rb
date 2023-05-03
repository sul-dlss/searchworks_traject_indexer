# frozen_string_literal: true

require_relative '../config/boot'

require 'folio_client'
require 'traject'
require 'traject/readers/folio_postgres_reader'
require 'traject/extractors/folio_kafka_extractor'
require 'parallel'

log_file = File.expand_path("../log/process_folio_postgres_to_kafka_#{Utils.env_config.kafka_topic}.log", __dir__)
Utils.set_log_file(log_file)

state_file = ENV['STATE_FILE'] || File.expand_path(
  "../tmp/searchworks_traject_folio_postgres_indexer_last_run_#{Utils.env_config.kafka_topic}", __dir__
)

# Make sure there's a valid last response date to parse from the state file
File.open(state_file, 'w') { |f| f.puts '1970-01-01T00:00:00Z' } unless File.exist? state_file

File.open(state_file, 'r+') do |f|
  abort "Unable to acquire lock on #{state_file}" unless f.flock(File::LOCK_EX | File::LOCK_NB)

  last_date = Time.iso8601(f.read.strip)
  Utils.logger.info "Found last_date in #{state_file}: #{last_date}"

  last_response_date = Traject::FolioPostgresReader.new(nil,
                                                        'postgres.url': ENV.fetch('DATABASE_URL')).last_response_date

  shards = if Utils.env_config.processes
             (0x0..0xf).to_a.map do |k|
               next_val = k + 1
               if next_val == 16
                 "vi.id >= 'f0000000-0000-0000-0000-000000000000'"
               else
                 "vi.id BETWEEN '#{k.to_s(16)}0000000-0000-0000-0000-000000000000' AND '#{next_val.to_s(16)}0000000-0000-0000-0000-000000000000'"
               end
             end
           else
             ['TRUE']
           end
  Parallel.map(shards, in_processes: Utils.env_config.processes.to_i) do |sql_filter|
    reader = Traject::FolioPostgresReader.new(nil, 'folio.updated_after': last_date.utc.iso8601,
                                                   'postgres.url': ENV.fetch('DATABASE_URL'), 'postgres.sql_filters': sql_filter)
    Traject::FolioKafkaExtractor.new(reader:, kafka: Utils.kafka, topic: Utils.env_config.kafka_topic).process!
  end

  Utils.logger.info "Response generated at: #{last_response_date} (previous: #{last_date})"

  if last_response_date > last_date
    f.rewind
    f.truncate(0)
    f.puts(last_response_date.iso8601)
    Utils.logger.info "Wrote new last date: #{last_response_date}"
  end
end
