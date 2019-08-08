$LOAD_PATH << File.expand_path('../..', __dir__)

require 'traject'
require 'stanford-mods'
require 'sdr_stuff'
require 'kafka'
require 'traject/readers/kafka_purl_fetcher_reader'
require 'traject/writers/solr_better_json_writer'
require 'utils'
require 'honeybadger'

Utils.logger = logger
extend Traject::SolrBetterJsonWriter::IndexerPatch

def log_skip(context)
  writer.put(context)
end

$druid_title_cache = {}

indexer = self

settings do
  provide 'writer_class_name', 'Traject::SolrBetterJsonWriter'
  provide 'solr.url', ENV['SOLR_URL']
  provide 'solr.version', ENV['SOLR_VERSION']
  provide 'purl_fetcher.skip_catkey', false
  provide 'processing_thread_pool', ENV['NUM_THREADS']
  provide 'solr_better_json_writer.debounce_timeout', 5
  if ENV['KAFKA_TOPIC']
    provide "reader_class_name", "Traject::KafkaPurlFetcherReader"
    kafka = Kafka.new(ENV.fetch('KAFKA', 'localhost:9092').split(','))
    consumer = kafka.consumer(group_id: ENV.fetch('KAFKA_CONSUMER_GROUP_ID', "traject_#{ENV['KAFKA_TOPIC']}"), fetcher_max_queue_size: 15)
    consumer.subscribe(ENV['KAFKA_TOPIC'])
    provide 'kafka.consumer', consumer
  end

  provide 'purl_fetcher.target', ENV.fetch('PURL_FETCHER_TARGET', 'Earthworks')
  provide 'solr_writer.commit_on_close', true
  if defined?(JRUBY_VERSION)
    require 'traject/manticore_http_client'
    provide 'solr_json_writer.http_client', Traject::ManticoreHttpClient.new
  else
    provide 'solr_json_writer.http_client', HTTPClient.new.tap { |x| x.receive_timeout = 600 }
  end
  provide 'solr_json_writer.skippable_exceptions', [HTTPClient::TimeoutError, StandardError]

  provide 'mapping_rescue', (lambda do |context, e|
    Honeybadger.notify(e, context: { record: context.record_inspect, index_step: context.index_step.inspect })

    indexer.send(:default_mapping_rescue).call(context, e)
  end)
end

def stanford_mods(method, *args, default: nil)
  lambda do |resource, accumulator, _context|
    data = Array(resource.stanford_mods.public_send(method, *args))

    data.each do |v|
      accumulator << v
    end

    accumulator << default if data.empty?
  end
end

def mods_xpath(xpath)
  lambda do |resource, accumulator, _context|
    accumulator << resource.mods.xpath(xpath, mods: 'http://www.loc.gov/mods/v3')
  end
end

def mods_display(method, *args, default: nil)
  lambda do |resource, accumulator, _context|
    data = Array(resource.mods_display.public_send(method, *args))

    data.each do |v|
      v.values.each do |v2|
        accumulator << v2.to_s
      end
    end

    accumulator << default if data.empty?
  end
end

each_record do |record, context|
  context.clipboard[:benchmark_start_time] = Time.now
end

##
# Skip records that have a delete field
each_record do |record, context|
  if record.is_a?(Hash) && record[:delete]
    context.output_hash['id'] = [record[:id].sub('druid:', '')]
    context.skip!('Delete')
  end
end

to_field 'dc_identifier_s' do |record, accumulator|
  accumulator << "http://purl.stanford.edu/#{record.druid}"
end

each_record do |record, context|
  context.skip!('This item is in processing or does not exist') unless record.public_xml?
  context.skip!(
    "This content type: #{record.dor_content_type} is not supported"
  ) unless %w[image map book].include?(record.dor_content_type)
  context.skip!('No ENVELOPE available') unless record.stanford_mods.geo_extensions_as_envelope.present?
end

to_field 'dc_title_s', stanford_mods(:sw_short_title, default: '[Untitled]')
to_field 'dc_description_s', mods_display(:abstract)
to_field 'dc_rights_s' do |record, accumulator|
  if record.public?
    accumulator << 'Public'
  elsif record.stanford_only?
    accumulator << 'Restricted'
  end
end
to_field 'layer_geom_type_s', literal('Image')
to_field 'dc_format_s', literal('JPEG 2000')
to_field 'dc_language_s', stanford_mods(:sw_language_facet), first_only
to_field 'dc_subject_sm', stanford_mods(:subject_all_search)
to_field 'dct_spatial_sm', stanford_mods(:geographic_facet)
to_field 'dc_publisher_s',
         stanford_mods(:term_values, %I[origin_info publisher]),
         first_only
to_field 'geoblacklight_version', literal('1.0')
to_field 'dct_references_s' do |record, accumulator|
  accumulator << {
    'http://schema.org/url' => "https://purl.stanford.edu/#{record.druid}",
    'https://oembed.com' => "https://purl.stanford.edu/embed.json?&hide_title=true&url=https://purl.stanford.edu/#{record.druid}",
    'http://iiif.io/api/presentation#manifest' => "https://purl.stanford.edu/#{record.druid}/iiif/manifest"
  }.to_json
end
to_field 'solr_geom', stanford_mods(:geo_extensions_as_envelope)
to_field 'layer_slug_s' do |record, accumulator|
  accumulator << "stanford-#{record.druid}"
end
to_field 'dct_provenance_s', literal('Stanford')
to_field 'stanford_rights_metadata_s' do |record, accumulator|
  accumulator << record.rights_xml
end

each_record do |record, context|
  $druid_title_cache[record.druid] = record.label if record.is_collection
end

each_record do |record, context|
  context.output_hash.select { |k, _v| k =~ /_struct$/ }.each do |k, v|
    context.output_hash[k] = Array(v).map { |x| JSON.generate(x) }
  end
end

each_record do |record, context|
  t0 = context.clipboard[:benchmark_start_time]
  t1 = Time.now

  logger.debug('geo_config.rb') { "Processed #{context.output_hash['id']} (#{t1 - t0}s)" }
end
