$LOAD_PATH << File.expand_path('../..', __dir__)

require 'traject'
require 'traject/readers/folio_reader'
require 'traject/writers/solr_better_json_writer'
require 'i18n'
require 'honeybadger'
require 'utils'

I18n.available_locales = [:en]

extend Traject::SolrBetterJsonWriter::IndexerPatch

Utils.logger = logger
indexer = self

settings do
  provide 'writer_class_name', 'Traject::SolrBetterJsonWriter'
  provide 'solr.url', ENV['SOLR_URL']
  provide 'processing_thread_pool', ENV['NUM_THREADS']
  provide 'reader_class_name', 'Traject::FolioReader'

  provide 'allow_duplicate_values',  false
  provide 'solr_writer.commit_on_close', true
  provide 'mapping_rescue', (lambda do |context, e|
    Honeybadger.notify(e, context: { record: context.record_inspect, index_step: context.index_step.inspect })

    indexer.send(:default_mapping_rescue).call(context, e)
  end)

  provide 'solr_json_writer.http_client', HTTPClient.new.tap { |x| x.receive_timeout = 600 }
  provide 'solr_json_writer.skippable_exceptions', [HTTPClient::TimeoutError, StandardError]
end


to_field 'id', extract_marc('001') do |_record, accumulator|
  accumulator.map! do |v|
    v.sub(/^a/, '')
  end
end
