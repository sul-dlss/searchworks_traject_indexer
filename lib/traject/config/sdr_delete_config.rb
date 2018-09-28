$LOAD_PATH << File.expand_path('../..', __dir__)

require 'traject'
require 'traject/readers/purl_fetcher_reader'
require 'traject/readers/purl_fetcher_deletes_reader'
require 'traject/writers/delete_writer'
require 'sdr_stuff'

settings do
  provide 'solr.url', ENV['SOLR_URL']
  provide 'solr.version', ENV['SOLR_VERSION']
  provide 'processing_thread_pool', ENV['NUM_THREADS']
  provide 'reader_class_name', 'Traject::PurlFetcherDeletesReader'
  provide 'writer_class_name', 'Traject::DeleteWriter'
  provide 'skip_if_catkey', 'true'
  provide 'solr_writer.commit_on_close', true
  if defined?(JRUBY_VERSION)
    require 'traject/manticore_http_client'
    provide 'solr_json_writer.http_client', Traject::ManticoreHttpClient.new
  else
    provide 'solr_json_writer.http_client', HTTPClient.new.tap { |x| x.receive_timeout = 600 }
  end
end

to_field 'id' do |record, accumulator|
  accumulator << record.druid.strip
end
