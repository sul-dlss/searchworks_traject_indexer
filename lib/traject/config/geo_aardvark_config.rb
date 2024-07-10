# frozen_string_literal: true

# rubocop:disable Style/CombinableLoops

require_relative '../../../config/boot'
require_relative '../macros/extras'
require_relative '../macros/cocina'
require_relative '../macros/geo'
require 'digest/md5'

Utils.logger = logger

# rubocop:disable Style/MixinUsage
extend Traject::SolrBetterJsonWriter::IndexerPatch
extend Traject::Macros::Cocina
extend Traject::Macros::Extras
extend Traject::Macros::Geo
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
  provide 'searchworks.url', ENV.fetch('SEARCHWORKS_URL', 'https://searchworks.stanford.edu')
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

# Time the indexing of each record
each_record do |_record, context|
  context.clipboard[:benchmark_start_time] = Time.now
end

# Skip records that have a delete field; id is needed to delete from the index
each_record do |record, context|
  next unless record.is_a?(Hash) && record[:delete]

  druid = record[:id].sub('druid:', '')
  context.output_hash['id'] = ["stanford-#{druid}"]
  logger.debug "Delete: #{druid}"
  context.skip!("Delete: #{druid}")
end

# Skip records with no public cocina
each_record do |record, context|
  next if record.public_cocina?

  message = 'No public metadata for item'
  SdrEvents.report_indexing_skipped(record.druid, target: settings['purl_fetcher.target'], message:)
  logger.warn "#{message}: #{record.druid}"
  context.skip!("#{message}: #{record.druid}")
end

# Skip records with content types that we can't index
each_record do |record, context|
  next if %w[image map book geo file object collection].include?(record.content_type)

  message = "Item content type \"#{record.content_type}\" is not supported"
  SdrEvents.report_indexing_skipped(record.druid, target: settings['purl_fetcher.target'], message:)
  logger.warn "#{message}: #{record.druid}"
  context.skip!("#{message}: #{record.druid}")
end

# https://opengeometadata.org/ogm-aardvark/#id
to_field 'id', druid, prepend('stanford-')

# https://opengeometadata.org/ogm-aardvark/#title
to_field 'dct_title_s', cocina_titles(type: :main), first_only, default('[Untitled]')

# https://opengeometadata.org/ogm-aardvark/#alternative-title
# - indexed but not displayed in the UI
to_field 'dct_alternative_sm', cocina_titles(type: :additional)

# https://opengeometadata.org/ogm-aardvark/#description
# - geo data usually has a note with type "abstract"
# - scanned maps usually have many short, non-typed and/or heterogenous notes
# - we only want to use certain notes for the description
# - we concatenate these as <p> elements in the UI
SKIP_NOTE_TYPES = ['Local note', 'Preferred citation', 'Supplemental information', 'Donor tags'].freeze
to_field 'dct_description_sm', cocina_descriptive('note'), select(->(note) { SKIP_NOTE_TYPES.exclude? note['displayLabel'] }), extract_values

# https://opengeometadata.org/ogm-aardvark/#language
to_field 'dct_language_sm', cocina_descriptive('language'), transform(->(lang) { lang['code'] })

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
# - currently unused in the UI
to_field 'gbl_dateRange_drsim', use_field('dct_temporal_sm'), extract_years, minmax, transform(->(years) { "[#{years.first} TO #{years.last}]" if years.any? })

# https://opengeometadata.org/ogm-aardvark/#index-year
# - used to power the year facet in the UI
to_field 'gbl_indexYear_im', use_field('dct_temporal_sm'), extract_years, minmax, transform(->(years) { (years.first.to_i..years.last.to_i).to_a if years.any? }), flatten

# https://opengeometadata.org/ogm-aardvark/#provider
to_field 'schema_provider_s', literal('Stanford')

# https://opengeometadata.org/ogm-aardvark/#identifier
# - we could add other links here if desired
to_field 'dct_identifier_sm', cocina_descriptive('purl')

# https://opengeometadata.org/ogm-aardvark/#resource-class
# - if the item is a collection, set the resource class to "Collections" (only)
# - if we didn't find anything, fall back to "Other" because the field is required
to_field 'gbl_resourceClass_sm', cocina_descriptive('form'), select_type('genre'), extract_values, translation_map('geo_resource_class')
to_field 'gbl_resourceClass_sm', cocina_descriptive('form'), select_type('genre'), extract_structured_values(flatten: true), translation_map('geo_resource_class')
to_field 'gbl_resourceClass_sm', cocina_descriptive('form'), select_type('form'), extract_values, translation_map('geo_resource_class')
to_field 'gbl_resourceClass_sm', cocina_descriptive('form'), select_type('form'), extract_structured_values(flatten: true), translation_map('geo_resource_class')
to_field 'gbl_resourceClass_sm', cocina_descriptive('geographic', 'form'), select_type('type'), extract_values, translation_map('geo_resource_class')
to_field 'gbl_resourceClass_sm', cocina_descriptive('subject', 'structuredValue'), select_type('genre'), extract_values, translation_map('geo_resource_class')
to_field('gbl_resourceClass_sm') { |_record, accumulator, context| accumulator << 'Other' if context.output_hash['gbl_resourceClass_sm'].blank? }
to_field('gbl_resourceClass_sm') { |record, _accumulator, context| context.output_hash['gbl_resourceClass_sm'] = ['Collections'] if record.public_cocina.collection? }

# https://opengeometadata.org/ogm-aardvark/#resource-type
to_field 'gbl_resourceType_sm', cocina_descriptive('form'), select_type('form'), extract_values, translation_map('geo_resource_type')
to_field 'gbl_resourceType_sm', cocina_descriptive('form'), select_type('form'), extract_structured_values(flatten: true), translation_map('geo_resource_type')
to_field 'gbl_resourceType_sm', cocina_descriptive('subject'), select_type('topic'), extract_values, translation_map('geo_resource_type')
to_field 'gbl_resourceType_sm', cocina_descriptive('geographic', 'form'), select_type('type'), extract_values, translation_map('geo_resource_type')

# https://opengeometadata.org/ogm-aardvark/#format
to_field 'dct_format_s', cocina_descriptive('geographic', 'form'), select_type('data format'), extract_values, translation_map('geo_format')
to_field 'dct_format_s', cocina_descriptive('geographic', 'form'), select_type('media type'), extract_values, translation_map('geo_format')
to_field 'dct_format_s', cocina_descriptive('form'), select_type('form'), extract_values, translation_map('geo_format')
to_field 'dct_format_s', cocina_structural('contains', 'structural', 'contains', 'hasMimeType'), translation_map('geo_format')

# https://opengeometadata.org/ogm-aardvark/#geometry
# - powers the map search in the UI
# - was required in schema v1.0 but is no longer a required field in Aardvark
# - geo data will have a bounding box as a geographic subject
# - scanned maps will have coordinates as a subject
to_field 'locn_geometry', cocina_descriptive('geographic', 'subject'), select_type('bounding box coordinates'), format_envelope_bbox, first_only
to_field 'locn_geometry', cocina_descriptive('subject'), select_type('map coordinates'), format_envelope_dms, first_only

# https://opengeometadata.org/ogm-aardvark/#bounding-box
# - will always be the same as locn_geometry since we use the ENVELOPE syntax
to_field('dcat_bbox') { |_record, accumulator, context| accumulator << context.output_hash['locn_geometry'].first if context.output_hash['locn_geometry'].present? }

# https://opengeometadata.org/ogm-aardvark/#georeferenced
# - currently unused in the UI
to_field('gbl_georeferenced_b') { |_record, accumulator, context| accumulator << true if context.output_hash['dct_title_s'].first.match?(/\(Raster Image\)/) }

# https://opengeometadata.org/ogm-aardvark/#member-of
# - links items to collections and collections to their items via a box on the show page
# - a separate 'relations' solr query using this field is performed in the app to render the box
to_field 'pcdm_memberOf_sm', cocina_structural('isMemberOf'), gsub('druid:', 'stanford-')

# https://opengeometadata.org/ogm-aardvark/#source
# - links items that were georeferenced to their original version
to_field 'dct_source_sm', cocina_descriptive('relatedResource'), select_type('has other format'),
         select(->(res) { res['displayLabel'] == 'Scanned map' }),
         transform(->(res) { res.fetch('identifier', []).dig(0, 'value') }),
         transform(->(purl) { "stanford-#{purl.split('/').last}" if purl })

# https://opengeometadata.org/ogm-aardvark/#rights_1
to_field 'dct_rights_sm', cocina_access('useAndReproductionStatement')

# https://opengeometadata.org/ogm-aardvark/#rights-holder
to_field 'dct_rightsHolder_sm', cocina_access('copyright')

# https://opengeometadata.org/ogm-aardvark/#license
to_field 'dct_license_sm', cocina_access('license')

# https://opengeometadata.org/ogm-aardvark/#access-rights
to_field('dct_accessRights_s') { |record, accumulator| accumulator << (record.public_cocina.public? ? 'Public' : 'Restricted') }

# https://opengeometadata.org/ogm-aardvark/#modified
# - required, but not used in the UI
# - use the most recent adminMetadata event, falling back to top-level dates
to_field 'gbl_mdModified_dt', cocina_descriptive('adminMetadata', 'event'), extract_dates, extract_values, parse_dates, sort(reverse: true), format_datetimes, first_only
to_field 'gbl_mdModified_dt', modified, format_datetimes
to_field 'gbl_mdModified_dt', created, format_datetimes

# https://opengeometadata.org/ogm-aardvark/#metadata-version
to_field 'gbl_mdVersion_s', literal('Aardvark')

# https://opengeometadata.org/ogm-aardvark/#wxs-identifier
# - needed to request layers from our GeoServer
to_field('gbl_wxsIdentifier_s') { |record, accumulator| accumulator << "druid:#{record.druid}" if record.content_type == 'geo' }

# https://opengeometadata.org/ogm-aardvark/#references
# - powers the map preview functionality, download links, and more
# - everything gets encoded as a single JSON object and serialized to a string
# - links are evaluated in a preset order to determine which one to use for the preview
# - all items get a PURL link
# - all non-collection items get an embed link
# - all geo items get a WMS link
# - vectors get a WFS link
# - rasters get a WCS link
# - index maps have a specially named geojson file that is linked
# - if XML metadata files exist (not in data.zip), we link them
# - data that is in geoJSON format (including index maps) gets a link to the spec
to_field 'dct_references_s', purl_url, as_reference('http://schema.org/url')
to_field 'dct_references_s', stacks_object_url, as_reference('http://schema.org/downloadUrl')
to_field 'dct_references_s', embed_url({ hide_title: true }), as_reference('https://oembed.com')
to_field 'dct_references_s', iiif_manifest_url, as_reference('http://iiif.io/api/presentation#manifest')
to_field 'dct_references_s', wms_url, as_reference('http://www.opengis.net/def/serviceType/ogc/wms')
to_field 'dct_references_s', wfs_url, as_reference('http://www.opengis.net/def/serviceType/ogc/wfs')
to_field 'dct_references_s', wcs_url, as_reference('http://www.opengis.net/def/serviceType/ogc/wcs')
to_field 'dct_references_s', searchworks_url, as_reference('https://schema.org/relatedLink')
to_field 'dct_references_s', find_file(/index_map\.(json|geojson)/), stacks_file_url, as_reference('https://openindexmaps.org')
to_field 'dct_references_s', find_file(/iso19139\.xml/), stacks_file_url, as_reference('http://www.isotc211.org/schemas/2005/gmd')
to_field 'dct_references_s', find_file(/iso19110\.xml/), stacks_file_url, as_reference('http://www.isotc211.org/schemas/2005/gco')
to_field 'dct_references_s', find_file(/fgdc\.xml/), stacks_file_url, as_reference('http://www.opengis.net/cat/csw/csdgm')
to_field 'dct_references_s', find_file(/\.geojson/), stacks_file_url, as_reference('http://geojson.org/geojson-spec.html')

# Make single-valued fields in solr into single values instead of arrays
# The DebugWriter doesn't like this, so skip it for that writer
unless settings['writer_class_name'] == 'Traject::DebugWriter'
  each_record do |_record, context|
    # Encode the references as a JSON string
    context.output_hash['dct_references_s'] = context.output_hash['dct_references_s'].reduce(:merge!).to_json

    # Pick the first value for single-valued fields
    context.output_hash.select { |k, _v| k =~ /_(s|b|dt|bbox|geometry)$/ }.each do |k, v|
      context.output_hash[k] = context.output_hash[k].first if v.is_a?(Array)
    end
  end
end

# Log the indexing time for each record
each_record do |record, context|
  t0 = context.clipboard[:benchmark_start_time]
  t1 = Time.now

  logger.debug "Processed #{record.druid} (#{t1 - t0}s)"
end

# rubocop:enable Style/CombinableLoops
