# frozen_string_literal: true

require_relative '../../../config/boot'
require_relative '../macros/cocina'
require_relative '../macros/mods'
require_relative '../macros/extras'
require 'digest/md5'
require 'active_support'

Utils.logger = logger

extend Traject::SolrBetterJsonWriter::IndexerPatch
extend Traject::Macros::Cocina
extend Traject::Macros::Mods
extend Traject::Macros::Extras
def log_skip(context)
  writer.put(context)
end

# Cache fetched info by druid (combo of catkey and label)
# Used for collections and constituents
cached_title_value = ->(record) { [record.searchworks_id, record.label].join('-|-') }
$druid_title_cache = {}

indexer = self

SdrEvents.configure

settings do
  provide 'writer_class_name', 'Traject::SolrBetterJsonWriter'
  provide 'solr.url', ENV.fetch('SOLR_URL', nil)

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

  provide 'purl_fetcher.target', ENV.fetch('PURL_FETCHER_TARGET', 'Searchworks')
  provide 'purl_fetcher.skip_catkey', ENV.fetch('PURL_FETCHER_SKIP_CATKEY', nil)
  self['purl_fetcher.skip_catkey'] = self['purl_fetcher.skip_catkey'] != 'false'

  provide 'solr_writer.commit_on_close', true
  provide 'solr_json_writer.http_client', HTTPClient.new.tap { |x| x.receive_timeout = 600 }
  provide 'solr_json_writer.skippable_exceptions', [HTTPClient::TimeoutError, StandardError]

  # On error, log to Honeybadger and report as SDR event if we can tie the error to a druid
  provide 'mapping_rescue', (lambda do |traject_context, err|
    context = { record: traject_context.record_inspect, index_step: traject_context.index_step.inspect }

    Honeybadger.notify(err, context:)

    begin
      druid = traject_context.source_record&.druid
      SdrEvents.report_indexing_errored(druid, target: 'Searchworks', message: err.message, context:) if druid
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
  context.output_hash['id'] = [druid]
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

# Skip records that probably have an equivalent MARC record
each_record do |record, context|
  next unless record.catkey

  message = 'Item has a catkey'
  SdrEvents.report_indexing_skipped(record.druid, target: settings['purl_fetcher.target'], message:)
  logger.debug "#{message}: #{record.druid}"
  context.skip!("#{message}: #{record.druid}")
end

# id is always the druid for SDR items
to_field 'id', cocina_display(:bare_druid)
to_field 'druid', cocina_display(:bare_druid)

# this is used for sitemap generation; pre-hashing the IDs helps with that process
to_field 'hashed_id_ssi', use_field('id'), transform(->(id) { Digest::MD5.hexdigest(id) })

# the entire mods XML record; currently used for display purposes
# TODO: remove this; see: https://github.com/sul-dlss/SearchWorks/issues/6396
to_field 'modsxml', stanford_mods(:to_xml)
to_field 'cocina_struct' do |record, accumulator|
  # These are the only subschemas we need. Identification for DOI, access for use and reproduction.
  accumulator << record.public_cocina.cocina_doc.slice('description', 'identification', 'access')
end

# flattened text of all nodes in the record for searching
to_field 'all_search', cocina_display(:text)

##
# Title Fields
to_field 'title_245a_search', cocina_display(:short_title), default('[Untitled]')
to_field 'title_245_search', cocina_display(:full_title), default('[Untitled]')
to_field 'title_sort', cocina_display(:sort_title), default('[Untitled]')
to_field 'title_display', cocina_display(:display_title), default('[Untitled]')
to_field 'title_full_display', cocina_display(:full_title), default('[Untitled]')
to_field 'title_variant_search', cocina_display(:additional_titles)

##
# Author Fields
to_field 'author_1xx_search', cocina_display(:main_contributor_name, with_date: true)
to_field 'author_7xx_search', cocina_display(:additional_contributor_names, with_date: true)
to_field 'author_person_facet', cocina_display(:person_contributor_names, with_date: true)
to_field 'author_other_facet', cocina_display(:impersonal_contributor_names)
to_field 'author_sort', cocina_display(:sort_contributor_name)
to_field 'author_corp_display', cocina_display(:organization_contributor_names)
to_field 'author_meeting_display', cocina_display(:conference_contributor_names)
to_field 'author_person_display', cocina_display(:person_contributor_names, with_date: true)
to_field 'author_person_full_display', cocina_display(:person_contributor_names, with_date: true)
to_field 'author_struct', cocina_display(:contributors), contributor_to_struct

##
# Subject Fields
to_field 'topic_search', cocina_display(:subject_topics)
to_field 'geographic_search', cocina_display(:subject_places)
to_field 'subject_other_search', cocina_display(:subject_other)
to_field 'subject_other_subvy_search', cocina_display(:subject_temporal_genre)
to_field 'subject_all_search', cocina_display(:subject_all)
to_field 'topic_facet', cocina_display(:subject_topics_other)
to_field 'geographic_facet', cocina_display(:subject_places)
to_field 'era_facet', cocina_display(:subject_temporal)

##
# Publication Fields
# TODO: remove pub_date and pub_date_sort; see: https://github.com/sul-dlss/SearchWorks/issues/6410
to_field 'pub_date', cocina_display(:pub_year_str)
to_field 'pub_date_sort', cocina_display(:pub_year_str)
to_field 'pub_search', cocina_display(:publication_places)
to_field 'publication_year_isi', cocina_display(:pub_year_int)
to_field 'pub_year_ss', cocina_display(:pub_year_str)
to_field 'imprint_display', cocina_display(:imprint_str)
to_field 'pub_country', cocina_display(:publication_countries)
to_field 'pub_year_tisim', cocina_display(:pub_year_ints)

##
# Form fields
to_field 'genre_ssim', cocina_display(:genres_search)
to_field 'physical', cocina_display(:extents)
to_field 'format_hsim', cocina_display(:searchworks_resource_types)
to_field 'language', cocina_display(:searchworks_language_names)
to_field 'stanford_work_facet_hsim', stanford_work_facet

##
# Note fields
to_field 'summary_search', cocina_display(:abstracts)
to_field 'toc_search', cocina_display(:tables_of_contents)

##
# Access fields
to_field 'iiif_manifest_url_ssim', iiif_manifest_url
to_field 'access_facet', literal('Online')
to_field 'library_code_facet_ssim', literal('SDR')
to_field 'building_facet', literal('Stanford Digital Repository')

##
# Identifier Fields
to_field 'isbn_search', cocina_display(:identifiers, type: 'isbn'), transform(&:identifier)
to_field 'isbn_display', cocina_display(:identifiers, type: 'isbn'), transform(&:identifier)
to_field 'issn_search', cocina_display(:identifiers, type: 'issn'), transform(&:identifier)
to_field 'issn_display', cocina_display(:identifiers, type: 'issn'), transform(&:identifier)
to_field 'lccn', cocina_display(:identifiers, type: 'lccn'), transform(&:identifier), first_only
to_field 'oclc', cocina_display(:identifiers, type: 'oclc'), transform(&:identifier)

##
# Structural metadata fields
to_field('dor_resource_count_isi') { |record, accumulator| accumulator << record.filesets.count }
to_field('file_id') { |record, accumulator| accumulator << record.thumbnail_file_id }

##
# Collection and constituent fields
to_field('collection_type') do |record, accumulator|
  accumulator << 'Digital Collection' if record.collection?
end

to_field 'collection' do |record, accumulator|
  accumulator.concat record.collections.map(&:searchworks_id)
end

to_field 'collection_with_title' do |record, accumulator|
  accumulator.concat(record.collections.map do |collection|
    $druid_title_cache[collection.druid] ||= cached_title_value.call(collection)
  end)
end

# This drives the AppearsInComponent in Searchworks (see fn851zf9475)
to_field 'set' do |record, accumulator|
  accumulator.concat record.parents.map(&:searchworks_id)
end

# This drives the "Appears In" section of the "Bibliographic information" in Searchworks (see fn851zf9475)
to_field 'set_with_title' do |record, accumulator|
  accumulator.concat(record.parents.map do |parent|
    $druid_title_cache[parent.druid] ||= cached_title_value.call(parent)
  end)
end

# Schema.org representation for the object
to_field 'schema_dot_org_struct', schema_dot_org_struct

##
# Indexer context / metadata fields
to_field 'context_source_ssi', literal('sdr')
to_field('context_version_ssi') { |_record, accumulator| accumulator << Utils.version }

# If this is a collection or virtual object, pre-cache its title info for members to use
each_record do |record, _context|
  $druid_title_cache[record.druid] = cached_title_value.call(record) if record.collection? || record.virtual_object?
end

# Convert any _struct fields to JSON strings for solr
each_record do |_record, context|
  context.output_hash.select { |k, _v| k =~ /_struct$/ }.each do |k, v|
    context.output_hash[k] = Array(v).map { |x| JSON.generate(x) }
  end
end

# Log time taken to process each record
each_record do |_record, context|
  t0 = context.clipboard[:benchmark_start_time]
  t1 = Time.now

  logger.debug('sdr_config.rb') { "Processed #{context.output_hash['id']} (#{t1 - t0}s)" }
end
