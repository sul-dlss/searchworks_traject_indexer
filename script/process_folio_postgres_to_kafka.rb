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

full_dump = ARGV[0] == 'full'

# Make sure there's a state file
File.open(state_file, 'w') { |f| f.puts '' } if !File.exist?(state_file) || full_dump

File.open(state_file, 'r+') do |f|
  abort "Unable to acquire lock on #{state_file}" unless f.flock(File::LOCK_EX | File::LOCK_NB)

  last_run_file_value = f.read.strip
  last_date = Time.iso8601(last_run_file_value) if last_run_file_value.present?

  Utils.logger.info "Found last_date in #{state_file}: #{last_date}" if last_date

  last_response_date = Traject::FolioPostgresReader.new(nil,
                                                        'postgres.url': Utils.env_config.database_url).last_response_date

  processes = Utils.env_config.full_dump_processes if full_dump
  processes ||= Utils.env_config.processes

  shards = if processes.to_i > 1
             step = Utils.env_config.step_size || 0x0100
             ranges = (0x0000..0xffff).step(step).each_cons(2).map { |(min, max)| min...max }
             ranges << (ranges.last.max..0xffff)
             ranges.map do |range|
               "vi.id BETWEEN '#{range.min.to_s(16).rjust(4, '0')}0000-0000-0000-0000-000000000000' AND '#{range.max.to_s(16).rjust(4, '0')}ffff-ffff-ffff-ffff-ffffffffffff'"
             end
           else
             ['TRUE']
           end
  counts = Parallel.map(shards, in_processes: processes.to_i) do |sql_filter|
    attempts ||= 1
    begin
      reader = Traject::FolioPostgresReader.new(nil, 'folio.updated_after': last_date&.utc&.iso8601,
                                                     'postgres.url': Utils.env_config.database_url, 'postgres.sql_filters': sql_filter)
      Traject::FolioKafkaExtractor.new(reader:, kafka: Utils.kafka, topic: Utils.env_config.kafka_topic).process!
    rescue PG::Error => e
      raise(e) if attempts > 5

      attempts += 1
      Utils.logger.info e.message
      sleep rand((2**attempts)..(2 * (2**attempts)))
      retry
    end
  end

  Utils.logger.info "Processed #{counts.sum} total records"
  Utils.logger.info "Response generated at: #{last_response_date} (previous: #{last_date})"

  if last_date.nil? || last_response_date > last_date
    f.rewind
    f.truncate(0)
    f.puts(last_response_date.iso8601)
    Utils.logger.info "Wrote new last date: #{last_response_date}"
  end
end
