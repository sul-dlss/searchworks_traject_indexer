# frozen_string_literal: true

# rubocop:disable Style/CombinableLoops

require_relative '../../../config/boot'
require_relative '../macros/cocina'
require 'digest/md5'

Utils.logger = logger

# rubocop:disable Style/MixinUsage
extend Traject::SolrBetterJsonWriter::IndexerPatch
extend Traject::Macros::Cocina
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
  provide 'allow_duplicate_values', false

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

# Get the right geoserver url for an item given its access rights
# @param record [PublicCocinaRecord] the item being indexed
def geoserver_url(record)
  record.public_cocina.public? ? settings['geoserver.pub_url'] : settings['geoserver.stan_url']
end

# Generate a stacks file url for a given item and file
# @param record [PublicCocinaRecord] the item being indexed
# @param file [Cocina::Models::File] the file to generate a url for
def stacks_file_url(record, file)
  "#{settings['stacks.url']}/file/druid:#{record.druid}/#{file.filename}"
end

# Find the (first) file in an item that matches the given filename
# Limit to only files that are in "object" type filesets (not "image", "preview", etc.)
# @param record [PublicCocinaRecord] the item being indexed
# @param filename [Regexp] the filename to match
def find_object_file(record, filename)
  record.cocina_structural.contains
        .select { |fileset| fileset.type == 'https://cocina.sul.stanford.edu/models/resources/object' }
        .flat_map { |fileset| fileset.structural.contains }
        .find { |file| file.filename.match? filename }
end

# Generate a solr-formatted ENVELOPE string from a bounding box
# @param coordinates [Array<Hash>] the bounding box coordinates
def format_envelope(coordinates = [])
  west = coordinates.find { |c| c[:type] == 'west' }.value
  east = coordinates.find { |c| c[:type] == 'east' }.value
  north = coordinates.find { |c| c[:type] == 'north' }.value
  south = coordinates.find { |c| c[:type] == 'south' }.value

  "ENVELOPE(#{west}, #{east}, #{north}, #{south})"
rescue StandardError
  raise "Error parsing bounding box coordinates: #{coordinates}"
end

# Extract all the parseable unique years from a list of dates and sort them
# @param dates [Array<String>] the list of dates
def extract_years(dates)
  dates.filter { |date| date.match?(/^\d{1,4}([–-]\d{1,4})?$/) }
       .flat_map { |date| date.split(/[–-]/) }
       .map(&:to_i)
       .sort
       .uniq
end

# Time the indexing of each record
each_record do |_record, context|
  context.clipboard[:benchmark_start_time] = Time.now
end

# Skip records that have a delete field; id is needed to delete from the index
each_record do |record, context|
  next unless record.is_a?(Hash) && record[:delete]

  druid = record[:id].sub('druid:', '')
  context.output_hash['id'] = ["stanford-#{druid}"]
  context.skip!("Delete: #{druid}")
end

# Skip records with no public cocina
each_record do |record, context|
  next if record.public_cocina?

  message = 'Item is in processing or does not exist'
  SdrEvents.report_indexing_skipped(record.druid, target: settings['purl_fetcher.target'], message:)
  context.skip!("#{message}: #{record.druid}")
end

# Skip records with content types that we can't index
each_record do |record, context|
  next if %w[image map book geo file object collection].include?(record.content_type)

  message = "Item content type \"#{record.content_type}\" is not supported"
  SdrEvents.report_indexing_skipped(record.druid, target: settings['purl_fetcher.target'], message:)
  context.skip!("#{message}: #{record.druid}")
end

# https://opengeometadata.org/ogm-aardvark/#id
to_field 'id', druid, prepend('stanford-')

# https://opengeometadata.org/ogm-aardvark/#title
to_field 'dct_title_s', cocina_titles(type: :main), first_only

# https://opengeometadata.org/ogm-aardvark/#alternative-title
to_field 'dct_alternative_sm', cocina_titles(type: :additional)

# https://opengeometadata.org/ogm-aardvark/#description
to_field 'dct_description_sm', cocina_descriptive('note'), select_type('abstract'), extract_values

# https://opengeometadata.org/ogm-aardvark/#language
to_field 'dct_language_sm', cocina_descriptive('language'), transform(&:code)

# https://opengeometadata.org/ogm-aardvark/#creator
to_field 'dct_creator_sm', cocina_descriptive('contributor'), select_role('creator'), extract_names

# https://opengeometadata.org/ogm-aardvark/#publisher
to_field 'dct_publisher_sm', cocina_descriptive('event', 'contributor'), select_role('publisher'), extract_names

# https://opengeometadata.org/ogm-aardvark/#date-issued
to_field 'dct_issued_s', cocina_descriptive('event', 'date'), select_type('publication'), extract_values, first_only

# https://opengeometadata.org/ogm-aardvark/#subject
to_field 'dct_subject_sm', cocina_descriptive('subject'), select_type('topic'), extract_values
to_field 'dct_subject_sm', cocina_descriptive('subject'), select_type('topic'), extract_structured_values(flatten: true)
to_field 'dct_subject_sm', cocina_descriptive('subject', 'structuredValue'), select_type('topic'), extract_values

# https://opengeometadata.org/ogm-aardvark/#spatial-coverage
to_field 'dct_spatial_sm', cocina_descriptive('subject'), select_type('place'), extract_values
to_field 'dct_spatial_sm', cocina_descriptive('subject'), select_type('place'), extract_structured_values(flatten: true)
to_field 'dct_spatial_sm', cocina_descriptive('subject', 'structuredValue'), select_type('place'), extract_values

# https://opengeometadata.org/ogm-aardvark/#theme
to_field 'dcat_theme_sm', cocina_descriptive('subject'), select_type('topic'), extract_values, translation_map('geo_theme')
to_field 'dcat_theme_sm', cocina_descriptive('subject'), select_type('topic'), extract_structured_values(flatten: true), translation_map('geo_theme')
to_field 'dcat_theme_sm', cocina_descriptive('subject', 'structuredValue'), select_type('topic'), extract_values, translation_map('geo_theme')

# https://opengeometadata.org/ogm-aardvark/#temporal-coverage
to_field 'dct_temporal_sm', cocina_descriptive('subject'), select_type('time'), extract_values
to_field 'dct_temporal_sm', cocina_descriptive('subject'), select_type('time'), extract_structured_values, join('–')
to_field 'dct_temporal_sm', cocina_descriptive('event'), select_type('validity'), extract_values
to_field 'dct_temporal_sm', cocina_descriptive('event'), select_type('validity'), extract_structured_values, join('–')

# https://opengeometadata.org/ogm-aardvark/#date-range
to_field 'gbl_dateRange_drsim' do |_record, accumulator, context|
  next if context.output_hash['dct_temporal_sm'].blank?

  dates = extract_years(context.output_hash['dct_temporal_sm'])
  accumulator << "[#{dates.first} TO #{dates.last}]" if dates.any?
end

# https://opengeometadata.org/ogm-aardvark/#index-year
to_field 'gbl_indexYear_im' do |_record, accumulator, context|
  next if context.output_hash['dct_temporal_sm'].blank?

  dates = extract_years(context.output_hash['dct_temporal_sm'])
  accumulator.concat (dates.first.to_i..dates.last.to_i).to_a if dates.any?
end

# https://opengeometadata.org/ogm-aardvark/#provider
to_field 'schema_provider_s', literal('Stanford')

# https://opengeometadata.org/ogm-aardvark/#identifier
to_field 'dct_identifier_sm', cocina_descriptive('purl')

# https://opengeometadata.org/ogm-aardvark/#resource-class
to_field 'gbl_resourceClass_sm', cocina_descriptive('form'), select_type('genre'), extract_values, translation_map('geo_resource_class')
to_field 'gbl_resourceClass_sm', cocina_descriptive('form'), select_type('genre'), extract_structured_values(flatten: true), translation_map('geo_resource_class')
to_field 'gbl_resourceClass_sm', cocina_descriptive('form'), select_type('form'), extract_values, translation_map('geo_resource_class')
to_field 'gbl_resourceClass_sm', cocina_descriptive('form'), select_type('form'), extract_structured_values(flatten: true), translation_map('geo_resource_class')
to_field 'gbl_resourceClass_sm', cocina_descriptive('geographic', 'form'), select_type('type'), extract_values, translation_map('geo_resource_class')
to_field('gbl_resourceClass_sm') { |record, accumulator| accumulator << 'Collections' if record.public_cocina.collection? }
to_field('gbl_resourceClass_sm') { |_record, accumulator, context| accumulator << 'Other' if context.output_hash['gbl_resourceClass_sm'].empty? }

# https://opengeometadata.org/ogm-aardvark/#resource-type
to_field 'gbl_resourceType_sm', cocina_descriptive('form'), select_type('form'), extract_values, translation_map('geo_resource_type')
to_field 'gbl_resourceType_sm', cocina_descriptive('form'), select_type('form'), extract_structured_values(flatten: true), translation_map('geo_resource_type')
to_field 'gbl_resourceType_sm', cocina_descriptive('subject'), select_type('topic'), extract_values, translation_map('geo_resource_type')
to_field 'gbl_resourceType_sm', cocina_descriptive('geographic', 'form'), select_type('type'), extract_values, translation_map('geo_resource_type')

# https://opengeometadata.org/ogm-aardvark/#file-size
# TODO?

# https://opengeometadata.org/ogm-aardvark/#format
to_field 'dct_format_s', cocina_descriptive('geographic', 'form'), select_type('data format'), extract_values, translation_map('geo_format')
to_field 'dct_format_s', cocina_descriptive('geographic', 'form'), select_type('media type'), extract_values, translation_map('geo_format')
to_field 'dct_format_s', cocina_descriptive('form'), select_type('form'), extract_values, translation_map('geo_format')
to_field('dct_format_s') { |_record, accumulator| accumulator.slice!(1, accumulator.length) }

# https://opengeometadata.org/ogm-aardvark/#geometry
to_field 'locn_geometry', cocina_descriptive('geographic', 'subject'), select_type('bounding box coordinates'), transform(->(subject) { format_envelope(subject.structuredValue) }), first_only

# https://opengeometadata.org/ogm-aardvark/#bounding-box
to_field 'dcat_bbox', cocina_descriptive('geographic', 'subject'), select_type('bounding box coordinates'), transform(->(subject) { format_envelope(subject.structuredValue) }), first_only

# https://opengeometadata.org/ogm-aardvark/#source
# TODO?

# https://opengeometadata.org/ogm-aardvark/#georeferenced
# TODO?

# https://opengeometadata.org/ogm-aardvark/#member-of
to_field 'pcdm_memberOf_sm', cocina_structural('isMemberOf'), gsub('druid:', 'stanford-')

# https://opengeometadata.org/ogm-aardvark/#rights_1
to_field 'dct_rights_sm', cocina_access('useAndReproductionStatement')

# https://opengeometadata.org/ogm-aardvark/#license
to_field 'dct_license_sm', cocina_access('license')

# https://opengeometadata.org/ogm-aardvark/#access-rights
to_field('dct_accessRights_s') { |record, accumulator| accumulator << (record.public_cocina.public? ? 'Public' : 'Restricted') }

# https://opengeometadata.org/ogm-aardvark/#modified
to_field('gbl_mdModified_dt') { |record, accumulator| accumulator << record.modified.strftime('%Y-%m-%dT%H:%M:%SZ') }

# https://opengeometadata.org/ogm-aardvark/#metadata-version
to_field 'gbl_mdVersion_s', literal('Aardvark')

# https://opengeometadata.org/ogm-aardvark/#wxs-identifier
to_field('gbl_wxsIdentifier_s') { |record, accumulator| accumulator << "druid:#{record.druid}" if record.content_type == 'geo' }

# https://opengeometadata.org/ogm-aardvark/#references
to_field 'dct_references_s' do |record, accumulator, context|
  # All items have a purl link
  references = { 'http://schema.org/url' => "#{settings['purl.url']}/#{record.druid}" }

  # Non-collection items have an embed link
  # TODO: should they have a stacks download link too?
  references.merge!('https://oembed.com' => "#{settings['purl.url']}/embed.json?hide_title=true&url=#{settings['purl.url']}/#{record.druid}") unless record.public_cocina.collection?

  # IIIF items have a IIIF manifest link
  references.merge!('http://iiif.io/api/presentation#manifest' => "#{settings['purl.url']}/#{record.druid}/iiif3/manifest") if %w[image map book].include? record.content_type

  # Geo items have a WMS link
  references.merge!('http://www.opengis.net/def/serviceType/ogc/wms' => "#{geoserver_url(record)}/wms") if record.content_type == 'geo'

  # Vectors have a WFS link
  references.merge!('http://www.opengis.net/def/serviceType/ogc/wfs' => "#{geoserver_url(record)}/wfs") if %w[GeoJSON Shapefile].intersect? context.output_hash['dct_format_s'].to_a

  # Rasters have a WCS link
  references.merge!('http://www.opengis.net/def/serviceType/ogc/wcs' => "#{geoserver_url(record)}/wcs") if %w[GeoTIFF ArcGRID].intersect? context.output_hash['dct_format_s'].to_a

  # If the item has a map index, link it
  if (file = find_object_file(record, /index_map\.(json|geojson)/))
    references.merge!('https://openindexmaps.org' => "#{settings['stacks.url']}/file/druid:#{record.druid}/#{file.filename}")
  end

  # If the item has ISO19139 metadata, link it
  if (file = find_object_file(record, /iso19139\.xml/))
    references.merge!('http://www.isotc211.org/schemas/2005/gmd/' => "#{settings['stacks.url']}/file/druid:#{record.druid}/#{file.filename}")
  end

  # If the item has ISO19110 metadata, link it
  if (file = find_object_file(record, /iso19110\.xml/))
    references.merge!('http://www.isotc211.org/schemas/2005/gco/' => "#{settings['stacks.url']}/file/druid:#{record.druid}/#{file.filename}")
  end

  # If the item has FGDC metadata, link it
  if (file = find_object_file(record, /fgdc\.xml/))
    references.merge!('http://www.opengis.net/cat/csw/csdgm' => "#{settings['stacks.url']}/file/druid:#{record.druid}/#{file.filename}")
  end

  # If the item has a GeoJSON file, link it
  if (file = find_object_file(record, /\.geojson/))
    references.merge!('http://geojson.org/geojson-spec.html' => "#{settings['stacks.url']}/file/druid:#{record.druid}/#{file.filename}")
  end

  # Encode everything as a JSON string
  accumulator << references.to_json
end

# rubocop:enable Style/CombinableLoops
