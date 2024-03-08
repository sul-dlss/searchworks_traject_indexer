# frozen_string_literal: true

# rubocop:disable Style/GlobalVars
# rubocop:disable Style/CombinableLoops

require_relative '../../../config/boot'
require 'digest/md5'

Utils.logger = logger

# rubocop:disable Style/MixinUsage
extend Traject::SolrBetterJsonWriter::IndexerPatch
# rubocop:enable Style/MixinUsage

def log_skip(context)
  writer.put(context)
end

$druid_title_cache = {}

indexer = self

SdrEvents.configure

# rubocop:disable Metrics/BlockLength
settings do
  provide 'writer_class_name', 'Traject::SolrBetterJsonWriter'
  provide 'solr.url', ENV.fetch('SOLR_URL', nil)
  provide 'solr_better_json_writer.debounce_timeout', 5

  # These parameters are expected on the command line if you want to connect to a kafka topic:
  # provide 'kafka.topic'
  # provide 'kafka.consumer_group_id'
  if self['kafka.topic']
    provide 'kafka.hosts', ::Settings.kafka.hosts
    provide 'kafka.client', Kafka.new(self['kafka.hosts'], logger: Utils.logger)
    provide 'reader_class_name', 'Traject::KafkaPurlFetcherReader'
    consumer = self['kafka.client'].consumer(group_id: self['kafka.consumer_group_id'] || 'traject', fetcher_max_queue_size: 15)
    consumer.subscribe(self['kafka.topic'])
    provide 'kafka.consumer', consumer
  else
    provide 'reader_class_name', 'Traject::DruidReader'
  end

  provide 'purl.url', ENV.fetch('PURL_URL', 'https://purl.stanford.edu')
  provide 'stacks.url', ENV.fetch('STACKS_URL', 'https://stacks.stanford.edu')
  provide 'geoserver.pub_url', ENV.fetch('GEOSERVER_PUB_URL', 'https://geowebservices.stanford.edu/geoserver')
  provide 'geoserver.stan_url', ENV.fetch('GEOSERVER_STAN_URL', 'https://geowebservices-restricted.stanford.edu/geoserver')

  provide 'purl_fetcher.target', ENV.fetch('PURL_FETCHER_TARGET', 'Earthworks')
  provide 'purl_fetcher.skip_catkey', false

  provide 'solr_writer.commit_on_close', true
  provide 'solr_json_writer.http_client', (HTTPClient.new.tap { |x| x.receive_timeout = 600 })
  provide 'solr_json_writer.skippable_exceptions', [HTTPClient::TimeoutError, StandardError]

  # On error, log to Honeybadger and report as SDR event if we can tie the error to a druid
  provide 'mapping_rescue', (lambda do |traject_context, err|
    context = { record: traject_context.record_inspect, index_step: traject_context.index_step.inspect }

    Honeybadger.notify(err, context:)

    begin
      druid = traject_context.source_record&.druid
      SdrEvents.report_indexing_errored(druid, target: 'Earthworks', message: err.message, context:) if druid
    rescue StandardError => e
      Honeybadger.notify(e, context:)
    end

    indexer.send(:default_mapping_rescue).call(traject_context, err)
  end)
end
# rubocop:enable Metrics/BlockLength

to_field 'dct_identifier_sm' do |record, accumulator|
  accumulator << "#{settings['purl.url']}/#{record.druid}"
end

to_field 'dct_title_s' do |record, accumulator|
  accumulator << record.title
end

# rubocop:enable Style/GlobalVars
# rubocop:enable Style/CombinableLoops
