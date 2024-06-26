# frozen_string_literal: true

require_relative '../config/boot'

require 'parallel'
require 'slop'

opts = Slop.parse do |o|
  o.on '--help' do
    puts o
    exit
  end
  o.string '--traject-env', default: nil
  o.string '--kafka-topic', 'The kafka topic used for writing records', default: Utils.env_config.kafka_topic
  o.bool '--verbose', default: false
  o.int '--processes', 'Number of parallel processes to spawn to handle querying', default: nil

  o.separator ''
  o.separator 'State management'
  o.string '--state-file', default: ENV.fetch('STATE_FILE', nil)
  o.bool '--no-state-file', 'do not use the state file to track the current query time', default: false
  o.bool '--full', 'enable full indexing (vs delta indexing, that uses the modified timestamp from the state file)', default: false

  o.separator ''
  o.separator 'SQL query options'
  o.array '--sql-query', 'a list of additional SQL filters to apply to the query'
  o.string '--sql-join', 'an additional SQL join query to apply to the underlying query', default: nil
  o.bool '--sql-debug', 'print the SQL query'

  o.separator ''
  o.separator 'Reading IDs from a file'
  o.string '--ids-file', 'A file containing a list of IDs to process', default: nil
  o.string '--catkeys-file', 'A file containing a list of hrids to process', default: nil
  o.int '--chunk-size', 'Number of IDs to process per query', default: 100
end

Utils.env = opts[:traject_env] if opts[:traject_env]

unless opts[:verbose]
  log_file = File.expand_path("../log/process_folio_postgres_to_kafka_#{opts[:kafka_topic]}.log", __dir__)
  Utils.set_log_file(log_file)
end

if Utils.in_blackout_period?
  Utils.logger.info 'Skipping processing due to blackout period'
  exit
end

state_file = opts[:state_file]
state_file ||= Tempfile.new('searchworks_traject_folio_postgres_indexer').path if opts[:no_state_file]
state_file ||= File.expand_path("../tmp/searchworks_traject_folio_postgres_indexer_last_run_#{opts[:kafka_topic]}", __dir__)

# Make sure there's a state file
File.open(state_file, 'w') { |f| f.puts '' } if !File.exist?(state_file) || opts[:full]

File.open(state_file, 'r+') do |f|
  abort "Unable to acquire lock on #{state_file}" unless f.flock(File::LOCK_EX | File::LOCK_NB)

  last_run_file_value = f.read.strip
  last_date = Time.iso8601(last_run_file_value) if last_run_file_value.present?

  Utils.logger.info "Found last_date in #{state_file}: #{last_date}" if last_date

  last_response_date = Traject::FolioPostgresReader.new(nil,
                                                        'postgres.url': Utils.env_config.database_url).sql_server_current_time

  processes = opts[:processes]
  processes ||= Utils.env_config.full_dump_processes if opts[:full]
  processes ||= Utils.env_config.processes

  shards = if opts[:ids_file]
             File.open(opts[:ids_file]).each_line.each_slice(opts[:chunk_size]).lazy.map do |slice|
               # FOLIO's native identifier exports are quoted, so we should to strip the quotes :shrug:
               ids = slice.map { |x| x.strip.delete_prefix('"').delete_suffix('"') }.map { |x| "'#{PG::Connection.escape_string(x)}'::uuid" }.join(', ')
               "vi.id IN (#{ids})"
             end
           elsif opts[:catkeys_file]
             File.open(opts[:catkeys_file]).each_line.each_slice(opts[:chunk_size]).lazy.map do |slice|
               # FOLIO's native identifier exports are quoted, so we should to strip the quotes :shrug:
               ids = slice.map { |x| x.strip.delete_prefix('"').delete_suffix('"') }.map { |x| "'#{PG::Connection.escape_string((x.match?(/^\d+$/) ? "a#{x}" : x).downcase)}'" }.join(', ')
               "lower(sul_mod_inventory_storage.f_unaccent(vi.jsonb ->> 'hrid'::text)) IN (#{ids})"
             end
           elsif processes.to_i > 1
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
                                                     'folio.version': Utils.env_config.folio_version,
                                                     'postgres.url': Utils.env_config.database_url,
                                                     'postgres.sql_filters': opts[:sql_query] + [sql_filter],
                                                     'postgres.addl_from': opts[:sql_join],
                                                     'cursor_type' => opts[:full] ? 'docs' : 'ids')

      Utils.logger.info reader.queries if opts[:sql_debug]
      Traject::FolioKafkaExtractor.new(reader:, kafka: Utils.kafka, topic: opts[:kafka_topic]).process!
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
