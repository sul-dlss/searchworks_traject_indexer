# $:.unshift File.expand_path(File.join("..", 'lib'), File.dirname(__FILE__))

require 'traject'
require 'memory_profiler'
require './lib/traject/readers/marc_combining_reader.rb'

# require 'byebug'; byebug
indexer = Traject::Indexer.new.tap do |i|
  # i.settings(
  #   'solr.url' => 'http://fake'
  # )
  i.load_config_file('./lib/traject/config/sirsi_config.rb')
end

puts RUBY_DESCRIPTION

marc_records = Traject::MarcCombiningReader.new('./uni_00000000_00499999.marc', {}).take(1000)
report = MemoryProfiler.report do
  marc_records.each do |rec|
    indexer.map_record rec
  end
end

$stdout = File.new("report-#{Time.now}.txt", 'w')
report.pretty_print

# puts report.pretty_print
