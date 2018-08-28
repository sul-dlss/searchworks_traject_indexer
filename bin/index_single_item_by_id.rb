require 'http'
require 'json'
require 'traject'

indexer = Traject::Indexer.new.tap do |i|
  i.load_config_file('./lib/traject/config/sirsi_config.rb')
end

url = "#{ENV['SOLRMARC_STORED_FIELDS_SOLR_BASE_URL']}/select?q=#{ENV.fetch('q', '*:*')}&fl=*&rows=1000&start=0&wt=json&fl=*"
response =  HTTP.get(url)
docs = JSON.parse(response)['response']['docs']
docs.each do |expected|
  record = MARC::XMLReader.new(StringIO.new(expected['marcxml'])).to_a.first
  indexer.process_record(record)
end

indexer.complete
