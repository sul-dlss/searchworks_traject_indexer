# frozen_string_literal: true

require_relative '../../../config/boot'
require 'digest/md5'
require 'active_support'

Utils.logger = logger
extend Traject::SolrBetterJsonWriter::IndexerPatch

def log_skip(context)
  writer.put(context)
end

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
    # Convert the xpath result (a Nokogiri nodeset) to a plain array.
    # This allows traject methods like first_only to work properly.
    accumulator.concat(resource.mods.xpath(xpath, mods: 'http://www.loc.gov/mods/v3'))
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

each_record do |_record, context|
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

to_field 'id' do |record, accumulator|
  accumulator << record.druid
end

to_field 'hashed_id_ssi' do |_record, accumulator, context|
  next unless context.output_hash['id']

  accumulator << Digest::MD5.hexdigest(context.output_hash['id'].first)
end

# Skip records with no public XML
each_record do |record, context|
  next if record.public_xml?

  message = 'Item is in processing or does not exist'
  SdrEvents.report_indexing_skipped(record.druid, target: settings['purl_fetcher.target'], message:)
  context.skip!("#{message}: #{record.druid}")
end

##
# Skip records that probably have an equivalent MARC record
each_record do |record, context|
  next unless record.catkey

  message = 'Item has a catkey'
  SdrEvents.report_indexing_skipped(record.druid, target: settings['purl_fetcher.target'], message:)
  context.skip!("#{message}: #{record.druid}")
end

to_field 'druid' do |record, accumulator|
  accumulator << record.druid
end

to_field 'modsxml', stanford_mods(:to_xml)
to_field 'all_search', stanford_mods(:text) do |_record, accumulator|
  accumulator.map! { |x| x.gsub(/\s+/, ' ') }
end

to_field 'collection_type' do |record, accumulator|
  accumulator << 'Digital Collection' if record.collection?
end

##
# Title Fields
to_field 'title_245a_search', stanford_mods(:sw_short_title, default: '[Untitled]')
to_field 'title_245_search', stanford_mods(:sw_full_title, default: '[Untitled]')
to_field 'title_variant_search', stanford_mods(:sw_addl_titles)
to_field 'title_sort', stanford_mods(:sw_sort_title, default: '[Untitled]')
to_field 'title_245a_display', stanford_mods(:sw_sort_title, default: '[Untitled]')
to_field 'title_display', stanford_mods(:sw_title_display, default: '[Untitled]')
to_field 'title_full_display', stanford_mods(:sw_full_title, default: '[Untitled]')

##
# Author Fields
to_field 'author_1xx_search', stanford_mods(:sw_main_author)
to_field 'author_7xx_search', stanford_mods(:sw_addl_authors)
to_field 'author_person_facet', stanford_mods(:sw_person_authors)
to_field 'author_other_facet', stanford_mods(:sw_impersonal_authors)
to_field 'author_sort', stanford_mods(:sw_sort_author)
to_field 'author_corp_display', stanford_mods(:sw_corporate_authors)
to_field 'author_meeting_display', stanford_mods(:sw_meeting_authors)
to_field 'author_person_display', stanford_mods(:sw_person_authors)
to_field 'author_person_full_display', stanford_mods(:sw_person_authors)

##
# Subject Fields
to_field 'topic_search', stanford_mods(:topic_search)
to_field 'geographic_search', stanford_mods(:geographic_search)
to_field 'subject_other_search', stanford_mods(:subject_other_search)
to_field 'subject_other_subvy_search', stanford_mods(:subject_other_subvy_search)
to_field 'subject_all_search', stanford_mods(:subject_all_search)
to_field 'topic_facet', stanford_mods(:topic_facet)
to_field 'geographic_facet', stanford_mods(:geographic_facet)
to_field 'era_facet', stanford_mods(:era_facet)

# TODO: need better implementation of pub_search in stanford-mods
to_field 'pub_search', stanford_mods(:place)
to_field 'pub_year_isi', stanford_mods(:pub_year_int) # for sorting
# deprecated pub_date_sort - use pub_year_isi; pub_date_sort is a string and requires weirdness for bc dates
#   can remove after pub_year_isi is populated for all indexing data (i.e. solrmarc, crez) and app code is changed
to_field 'pub_date_sort', stanford_mods(:pub_year_sort_str)
to_field 'imprint_display', stanford_mods(:imprint_display_str)
to_field 'pub_country',
         mods_xpath('mods:originInfo/mods:place/mods:placeTerm[@type="code"][@authority="marccountry" or @authority="iso3166"]') do |_record, accumulator|
  accumulator.map!(&:text).map!(&:strip)
  translation_map = Traject::TranslationMap.new('country_map')
  accumulator.replace [translation_map.translate_array(accumulator).first]
end
# deprecated pub_date Solr field - use pub_year_isi for sort key; pub_year_ss for display field
#   can remove after other fields are populated for all indexing data (i.e. solrmarc, crez) and app code is changed
to_field 'pub_date', stanford_mods(:pub_year_display_str)
to_field 'pub_year_ss', stanford_mods(:pub_year_display_str)

to_field 'beginning_year_isi',
         mods_xpath('mods:originInfo[mods:issuance/text()="continuing" or mods:issuance/text()="serial" or mods:issuance/text()="integrating resource"]/mods:dateIssued[@point="start"]'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| v.to_i.to_s unless v.empty? }
end

to_field 'ending_year_isi',
         mods_xpath('mods:originInfo[mods:issuance/text()="continuing" or mods:issuance/text()="serial" or mods:issuance/text()="integrating resource"]/mods:dateIssued[@point="end"]'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| v.to_i.to_s unless v.empty? }
end

to_field 'earliest_year_isi',
         mods_xpath('//mods:mods[mods:typeOfResource[@collection="yes"]]/mods:originInfo/mods:dateCreated[@point="start"]'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| v.to_i.to_s unless v.empty? }
end

to_field 'latest_year_isi',
         mods_xpath('//mods:mods[mods:typeOfResource[@collection="yes"]]/mods:originInfo/mods:dateCreated[@point="end"]'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| v.to_i.to_s unless v.empty? }
end

to_field 'earliest_poss_year_isi',
         mods_xpath('mods:originInfo/mods:dateCreated[@point="start"][@qualifier]|mods:originInfo/mods:dateIssued[@point="start"][@qualifier]'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| v.to_i.to_s unless v.empty? }
end

to_field 'latest_poss_year_isi',
         mods_xpath('mods:originInfo/mods:dateCreated[@point="end"][@qualifier]|mods:originInfo/mods:dateIssued[@point="end"][@qualifier]'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| v.to_i.to_s unless v.empty? }
end

to_field 'release_year_isi', mods_xpath('mods:originInfo[@eventType="distribution"]/mods:dateIssued'),
         first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| v.to_i.to_s unless v.empty? }
end

to_field 'production_year_isi', mods_xpath('mods:originInfo[@eventType="production"]/mods:dateIssued'),
         first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| v.to_i.to_s unless v.empty? }
end

to_field 'copyright_year_isi', mods_xpath('mods:originInfo/mods:copyrightDate'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| v.to_i.to_s unless v.empty? }
end

# TODO: need better implementation for date slider in stanford-mods (e.g. multiple years when warranted)
to_field 'pub_year_tisim', stanford_mods(:pub_year_int)

to_field 'creation_year_isi' do |record, accumulator|
  accumulator << record.stanford_mods.pub_year_int([:dateCreated])
end
to_field 'publication_year_isi' do |record, accumulator|
  accumulator << record.stanford_mods.pub_year_int([:dateIssued])
end

to_field 'format_main_ssim', stanford_mods(:format_main)
to_field 'genre_ssim', stanford_mods(:sw_genre)
to_field 'language', stanford_mods(:sw_language_facet)
to_field 'physical', stanford_mods(:term_values, %i[physical_description extent])
to_field 'summary_search', mods_display(:abstract)
to_field 'toc_search', stanford_mods(:term_values, :tableOfContents)
to_field 'url_suppl', stanford_mods(:term_values, %i[related_item location url])

to_field 'url_fulltext' do |record, accumulator|
  accumulator << "#{settings['purl.url']}/#{record.druid}"
end

to_field 'access_facet', literal('Online')
to_field 'building_facet', literal('Stanford Digital Repository')

to_field 'isbn_search', stanford_mods(:identifier) do |_record, accumulator|
  accumulator.compact!
  accumulator.select! { |identifier| identifier.type_at == 'isbn' }
  accumulator.map! { |identifier| identifier.text }
end

to_field 'issn_search', stanford_mods(:identifier) do |_record, accumulator|
  accumulator.compact!
  accumulator.select! { |identifier| identifier.type_at == 'issn' }
  accumulator.map! { |identifier| identifier.text }
end

to_field 'isbn_display', stanford_mods(:identifier) do |_record, accumulator|
  accumulator.compact!
  accumulator.select! { |identifier| identifier.type_at == 'isbn' }
  accumulator.map! { |identifier| identifier.text }
end

to_field 'issn_display', stanford_mods(:identifier) do |_record, accumulator|
  accumulator.compact!
  accumulator.select! { |identifier| identifier.type_at == 'issn' }
  accumulator.map! { |identifier| identifier.text }
end

to_field 'lccn', stanford_mods(:identifier) do |_record, accumulator|
  accumulator.compact!
  accumulator.select! { |identifier| identifier.type_at == 'lccn' }
  accumulator.map! { |identifier| identifier.text }
  accumulator.replace [accumulator.first] if accumulator.first # grab only the first value
end

to_field 'oclc', stanford_mods(:identifier) do |_record, accumulator|
  accumulator.compact!
  accumulator.select! { |identifier| identifier.type_at == 'oclc' }
  accumulator.map! { |identifier| identifier.text }
end

to_field 'file_id' do |record, accumulator|
  accumulator << record.thumb
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
  accumulator.concat record.constituents.map(&:searchworks_id)
end

# This drives the "Appears In" section of the "Bibliograpic information" in Searchworks (see fn851zf9475)
to_field 'set_with_title' do |record, accumulator|
  accumulator.concat(record.constituents.map do |constituent|
    $druid_title_cache[constituent.druid] ||= cached_title_value.call(constituent)
  end)
end

to_field 'schema_dot_org_struct' do |record, accumulator, context|
  ## Schema.org representation for content type geo objects
  if record.dor_content_type == 'geo'
    schema_dot_org_json = {
      '@context': 'http://schema.org',
      '@type': 'Dataset',
      citation: record.mods.xpath('//mods:note[@displayLabel="Preferred citation"]', mods: 'http://www.loc.gov/mods/v3').text,
      identifier: context.output_hash['url_fulltext'],
      license: record.mods.xpath('//mods:accessCondition[@type="license"]', mods: 'http://www.loc.gov/mods/v3').text,
      name: context.output_hash['title_display'],
      description: context.output_hash['summary_search'],
      sameAs: "https://searchworks.stanford.edu/view/#{record.druid}",
      keywords: context.output_hash['subject_all_search'],
      distribution: [
        {
          '@type': 'DataDownload',
          encodingFormat: 'application/zip',
          contentUrl: "https://stacks.stanford.edu/file/druid:#{record.druid}/data.zip"
        }
      ]
    }
    schema_dot_org_json['includedInDataCatalog'] = {
      '@type': 'DataCatalog',
      name: 'https://earthworks.stanford.edu'
    } if record.released_to_earthworks?
    accumulator << schema_dot_org_json
  end
end

# # Stanford student work facet
#  it is expected that these values will go to a field analyzed with
#   solr.PathHierarchyTokenizerFactory  so a value like
#    "Thesis/Dissertation|Master's|Engineer"
#  will be indexed as 3 values:
#    "Thesis/Dissertation|Master's|Engineer"
#    "Thesis/Dissertation|Master's"
#    "Thesis/Dissertation"
to_field 'stanford_work_facet_hsim' do |record, accumulator|
  genre = record.stanford_mods.sw_genre.to_a

  if genre.include? 'student project report'
    accumulator << 'Other student work|Student report'
  elsif genre.include? 'thesis'
    collections = record.collections

    collections.each do |c|
      accumulator << case c.label
                     when /phd/i
                       'Thesis/Dissertation|Doctoral|Unspecified'
                     when /master/i
                       'Thesis/Dissertation|Master\'s|Unspecified'
                     when /honor/i
                       'Thesis/Dissertation|Bachelor\'s|Undergraduate honors thesis'
                     when /capstone/i, /undergraduate/i
                       'Thesis/Dissertation|Bachelor\'s|Unspecified'
                     else
                       'Thesis/Dissertation|Unspecified'
                     end
    end
  end
end

to_field 'author_struct' do |record, accumulator|
  record.mods_display.name.each do |name|
    name.values.each do |value|
      accumulator << {
        link: value.name,
        search: "\"#{value.name}\"",
        post_text: ("(#{name.label.gsub(/:$/, '')})" if !name.label.nil? && !name.label.empty?)
      }
    end
  end
end

to_field 'iiif_manifest_url_ssim' do |record, accumulator|
  if %w[image manuscript map book].include?(record.dor_content_type)
    accumulator << "#{settings['purl.url']}/#{record.druid}/iiif/manifest"
  end
end

to_field 'dor_content_type_ssi' do |record, accumulator|
  accumulator << record.dor_content_type if record.dor_content_type.present?
end

to_field 'dor_resource_content_type_ssim' do |record, accumulator|
  record.dor_resource_content_type.uniq.each do |type|
    accumulator << type
  end
end

to_field 'dor_file_mimetype_ssim' do |record, accumulator|
  record.dor_file_mimetype.uniq.each do |mimetype|
    accumulator << mimetype
  end
end

to_field 'dor_resource_count_isi' do |record, accumulator|
  accumulator << record.dor_resource_count
end

# For finding fixtures with different types. Not currently used in Searchworks
# The possible values are: "world", "group", "none", or "location"
to_field 'dor_read_rights_ssim' do |record, accumulator|
  record.dor_read_rights.uniq.each do |right|
    accumulator << right
  end
end

to_field 'context_source_ssi', literal('sdr')

to_field 'context_version_ssi' do |_record, accumulator|
  accumulator << Utils.version
end

each_record do |record, _context|
  $druid_title_cache[record.druid] = cached_title_value.call(record) if record.collection?
end

each_record do |_record, context|
  context.output_hash.select { |k, _v| k =~ /_struct$/ }.each do |k, v|
    context.output_hash[k] = Array(v).map { |x| JSON.generate(x) }
  end
end

each_record do |_record, context|
  t0 = context.clipboard[:benchmark_start_time]
  t1 = Time.now

  logger.debug('sdr_config.rb') { "Processed #{context.output_hash['id']} (#{t1 - t0}s)" }
end
