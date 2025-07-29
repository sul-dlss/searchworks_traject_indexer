# frozen_string_literal: true

require_relative '../config/boot'
require 'slop'

opts = Slop.parse do |o|
  o.on '--help' do
    puts o
    exit
  end
  o.string '--traject-env', default: nil
  o.bool '--verbose', default: false
  o.separator ''
  o.separator 'SQL query options'
  o.array '--sql-query', 'a list of additional SQL filters to apply to the query'
  o.string '--sql-join', 'an additional SQL join query to apply to the underlying query', default: nil
  o.bool '--sql-debug', 'print the SQL query'
end

Utils.env = opts[:traject_env] if opts[:traject_env]

shards = begin
  step = Utils.env_config.step_size || 0x0008 # ~1.5k items
  ranges = (0x0000..0xffff).step(step).each_cons(2).map { |(min, max)| min...max }
  ranges << (ranges.last.max..0xffff)
  ranges.map do |range|
    "vi.id BETWEEN '#{range.min.to_s(16).rjust(4, '0')}0000-0000-0000-0000-000000000000' AND '#{range.max.to_s(16).rjust(4, '0')}ffff-ffff-ffff-ffff-ffffffffffff'"
  end
end

start_time = Time.now
sql_filter = shards.sample
attempts ||= 1
counts = []
puts sql_filter
begin
  puts ''
  reader = Traject::FolioPostgresReader.new(nil, 'folio.version': Utils.env_config.folio_version,
                                                 'postgres.url': Utils.env_config.database_url || ENV.fetch('DATABASE_URL', nil),
                                                 'postgres.sql_filters': [sql_filter],
                                                 'cursor_type' => 'docs')

  reader.each_with_index do |_record, i|
    print "\r#{i}"
    counts[0] = i
  end
rescue PG::Error => e
  raise(e) if attempts > 5

  attempts += 1
  Utils.logger.info e.message
  sleep rand((2**attempts)..(2 * (2**attempts)))
  retry
end
puts '.'

# 100 records/second is a good target
Utils.logger.info "Processed #{counts.sum} total records in #{Time.now - start_time}s"
