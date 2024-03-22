# frozen_string_literal: true

require_relative '../../../config/boot'
require 'digest/md5'

Utils.logger = logger

# rubocop:disable Style/MixinUsage
extend Traject::SolrBetterJsonWriter::IndexerPatch
# rubocop:enable Style/MixinUsage

def log_skip(context)
  writer.put(context)
end

indexer = self

SdrEvents.configure

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

def get_descriptive_value(record, field)
  record.cocina_description.public_send(field).map(&:value).join(' ')
end

def identifier_for(record)
  "#{settings['purl.url']}/#{record.druid}"
end

to_field 'id' do |record, accumulator|
  accumulator << identifier_for(record)
end

to_field 'dct_identifier_sm' do |record, accumulator|
  accumulator << identifier_for(record)
end

to_field 'dct_title_s' do |record, accumulator|
  accumulator << record.title
end

to_field 'dct_description_sm' do |record, accumulator|
  accumulator << get_descriptive_value(record, 'note')
end

to_field 'dct_accessRights_s' do |record, accumulator|
  if record.public?
    accumulator << 'Public'
  elsif record.stanford_only?
    accumulator << 'Restricted'
  end
end

to_field 'gbl_resourceType_sm' do |record, accumulator|
  next unless record.resource_type

  accumulator << record.resource_type.value.gsub('Dataset#', '')
end

to_field 'gbl_mdModified_dt' do |record, accumulator|
  next unless record.publication_date

  accumulator << record.publication_date.value
end

to_field 'dct_issued_s'do |record, accumulator|
  next unless record.publication_date

  accumulator << record.publication_date.value
end

to_field 'dc_format_s' do |record, accumulator|
  next unless record.data_format

  accumulator << record.data_format.value
end

to_field 'dct_language_sm' do |record, accumulator|
  next unless record.languages

  accumulator << record.languages.first[:code]
end

to_field 'dct_subject_sm' do |record, accumulator|
  next unless record.topics

  accumulator.concat(record.topics.map(&:value))
end

to_field 'dct_spatial_sm' do |record, accumulator|
  next unless record.geographic_spatial

  accumulator << record.geographic_spatial.value
end

to_field 'dct_creator_sm' do |record, accumulator|
  next unless record.creators

  record.creators.each do |creator|
    accumulator << creator.name.map(&:value)
  end
  accumulator.flatten!
end

to_field 'dct_publisher_sm' do |record, accumulator|
  next unless record.publishers

  record.publishers.each do |publisher|
    accumulator << publisher.name.map(&:value)
  end
  accumulator.flatten!
end

to_field 'dcat_theme_sm' do |record, accumulator|
  next unless record.themes

  record.themes.each do |theme|
    accumulator << theme.value
  end
end

to_field 'dct_temporal_sm' do |record, accumulator|
  next unless record.temporal

  accumulator.replace(record.temporal.flatten)
end

to_field 'gbl_dateRange_drsim' do |record, accumulator|
  next unless record.temporal

  record.temporal.each do |range|
    accumulator << "#{range.first} TO #{range.last}"
  end
end

to_field 'gbl_indexYear_im' do |record, accumulator|
  next unless record.temporal

  record.temporal.each do |range|
    accumulator << (range.first.to_i..range.last.to_i).to_a
  end
  accumulator.flatten!.uniq
end

to_field 'schema_provider_s', literal('Stanford')

# to_field 'dct_alternative_sm'

# to_field 'gbl_resourceClass_sm'
# to_field 'gbl_fileSize_s'
# to_field 'locn_geometry'
# to_field 'dcat_bbox'
# to_field 'dct_source_sm'
# to_field 'gbl_georeferenced_b'
# to_field 'pcdm_memberOf_sm'
# to_field 'dct_rights_sm'
# to_field 'dct_license_sm'
# to_field 'gbl_mdVersion_s'
# to_field 'gbl_suppressed_b'
# to_field 'gbl_wxsIdentifier_s'
# to_field 'dct_references_s'