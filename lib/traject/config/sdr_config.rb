$LOAD_PATH << File.expand_path('../..', __dir__)

require 'traject'
require 'stanford-mods'
require 'sdr_stuff'
require 'traject/readers/purl_fetcher_reader'

$druid_title_cache = {}

settings do
  provide 'solr.url', ENV['SOLR_URL']
  provide 'solr.version', ENV['SOLR_VERSION']
  provide 'processing_thread_pool', ENV['NUM_THREADS']
  provide 'reader_class_name', 'PurlFetcherReader'
  provide 'skip_if_catkey', 'true'
  provide 'solr_writer.commit_on_close', true
  if defined?(JRUBY_VERSION)
    require 'traject/manticore_http_client'
    provide 'solr_json_writer.http_client', Traject::ManticoreHttpClient.new
  else
    provide 'solr_json_writer.http_client', HTTPClient.new.tap { |x| x.receive_timeout = 600 }
  end
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
  context.skip!('This item is in processing or does not exist') unless record.public_xml?
end

##
# Skip records that probably have an equivalent MARC record
each_record do |record, context|
  context.skip!('Item has a catkey') if context.settings['skip_if_catkey'] == 'true' && record.catkey
end

to_field 'id' do |record, accumulator|
  accumulator << record.druid
end

to_field 'druid' do |record, accumulator|
  accumulator << record.druid
end

to_field 'modsxml', stanford_mods(:to_xml)
to_field 'all_search', stanford_mods(:text) do |record, accumulator|
  accumulator.map! { |x| x.gsub(/\s+/, ' ') }
end

to_field 'collection_type' do |record, accumulator|
  accumulator << 'Digital Collection' if record.is_collection
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
to_field 'pub_country', mods_xpath('mods:originInfo/mods:place/mods:placeTerm[@type="code"][@authority="marccountry" or @authority="iso3166"]') do |_record, accumulator|
  accumulator.map!(&:text).map!(&:strip)
  translation_map = Traject::TranslationMap.new('country_map')
  accumulator.replace [translation_map.translate_array(accumulator).first]
end
# deprecated pub_date Solr field - use pub_year_isi for sort key; pub_year_ss for display field
#   can remove after other fields are populated for all indexing data (i.e. solrmarc, crez) and app code is changed
to_field 'pub_date', stanford_mods(:pub_year_display_str)
to_field 'pub_year_ss', stanford_mods(:pub_year_display_str)

to_field 'beginning_year_isi', mods_xpath('mods:originInfo[mods:issuance/text()="continuing" or mods:issuance/text()="serial" or mods:issuance/text()="integrating resource"]/mods:dateIssued[@point="start"]'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| Time.new(v).year.to_s unless v.empty? }
end

to_field 'ending_year_isi', mods_xpath('mods:originInfo[mods:issuance/text()="continuing" or mods:issuance/text()="serial" or mods:issuance/text()="integrating resource"]/mods:dateIssued[@point="end"]'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| Time.new(v).year.to_s unless v.empty? }
end

to_field 'earliest_year_isi', mods_xpath('//mods:mods[mods:typeOfResource[@collection="yes"]]/mods:originInfo/mods:dateCreated[@point="start"]'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| Time.new(v).year.to_s unless v.empty? }
end

to_field 'latest_year_isi', mods_xpath('//mods:mods[mods:typeOfResource[@collection="yes"]]/mods:originInfo/mods:dateCreated[@point="end"]'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| Time.new(v).year.to_s unless v.empty? }
end

to_field 'earliest_poss_year_isi', mods_xpath('mods:originInfo/mods:dateCreated[@point="start"][@qualifier]|mods:originInfo/mods:dateIssued[@point="start"][@qualifier]'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| Time.new(v).year.to_s unless v.empty? }
end

to_field 'latest_poss_year_isi', mods_xpath('mods:originInfo/mods:dateCreated[@point="end"][@qualifier]|mods:originInfo/mods:dateIssued[@point="end"][@qualifier]'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| Time.new(v).year.to_s unless v.empty? }
end


to_field 'release_year_isi', mods_xpath('mods:originInfo[@eventType="distribution"]/mods:dateIssued'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| Time.new(v).year.to_s unless v.empty? }
end

to_field 'production_year_isi', mods_xpath('mods:originInfo[@eventType="production"]/mods:dateIssued'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| Time.new(v).year.to_s unless v.empty? }
end

to_field 'copyright_year_isi', mods_xpath('mods:originInfo/mods:copyrightDate'), first_only do |_record, accumulator|
  accumulator.map!(&:text).map! { |v| Time.new(v).year.to_s unless v.empty? }
end

# TODO: need better implementation for date slider in stanford-mods (e.g. multiple years when warranted)
to_field 'pub_year_tisim', stanford_mods(:pub_year_int)

to_field 'creation_year_isi' do |record, accumulator|
  accumulator << record.stanford_mods.year_int(record.stanford_mods.date_created_elements)
end
to_field 'publication_year_isi' do |record, accumulator|
  accumulator << record.stanford_mods.year_int(record.stanford_mods.date_issued_elements)
end

to_field 'format_main_ssim', stanford_mods(:format_main)
to_field 'genre_ssim', stanford_mods(:sw_genre)
to_field 'language', stanford_mods(:sw_language_facet)
to_field 'physical', stanford_mods(:term_values, [:physical_description, :extent])
to_field 'summary_search', stanford_mods(:term_values, :abstract)
to_field 'toc_search', stanford_mods(:term_values, :tableOfContents)
to_field 'url_suppl', stanford_mods(:term_values, [:related_item, :location, :url])


to_field 'url_fulltext' do |record, accumulator|
  accumulator << "https://purl.stanford.edu/#{record.druid}"
end

to_field 'access_facet', literal('Online')
to_field 'building_facet', literal('Stanford Digital Repository')

to_field 'isbn_search', stanford_mods(:identifier) do |record, accumulator|
  accumulator.compact!
  accumulator.select! { |identifier| identifier.type_at == 'isbn' }
  accumulator.map! { |identifier| identifier.text }
end

to_field 'issn_search', stanford_mods(:identifier) do |record, accumulator|
  accumulator.compact!
  accumulator.select! { |identifier| identifier.type_at == 'issn' }
  accumulator.map! { |identifier| identifier.text }
end

to_field 'isbn_display', stanford_mods(:identifier) do |record, accumulator|
  accumulator.compact!
  accumulator.select! { |identifier| identifier.type_at == 'isbn' }
  accumulator.map! { |identifier| identifier.text }
end

to_field 'issn_display', stanford_mods(:identifier) do |record, accumulator|
  accumulator.compact!
  accumulator.select! { |identifier| identifier.type_at == 'issn' }
  accumulator.map! { |identifier| identifier.text }
end

to_field 'lccn', stanford_mods(:identifier) do |record, accumulator|
  accumulator.compact!
  accumulator.select! { |identifier| identifier.type_at == 'lccn' }
  accumulator.map! { |identifier| identifier.text }
  accumulator.replace [accumulator.first] if accumulator.first # grab only the first value
end

to_field 'oclc', stanford_mods(:identifier) do |record, accumulator|
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
    $druid_title_cache[collection.druid] ||= "#{collection.searchworks_id}-|-#{collection.label}"
  end)
end

to_field 'set' do |record, accumulator|
  accumulator.concat record.constituents.map(&:searchworks_id)
end

to_field 'set_with_title' do |record, accumulator|
  accumulator.concat(record.constituents.map do |constituent|
    $druid_title_cache[constituent.druid] ||= "#{constituent.searchworks_id}-|-#{constituent.label}"
  end)
end

to_field 'schema_dot_org_struct' do |record, accumulator, context|
  ## Schema.org representation for content type geo objects
  if record.dor_content_type == 'geo'
    accumulator << {
      '@context': 'http://schema.org',
      '@type': 'Dataset',
      citation: record.mods.xpath('//mods:note[@displayLabel="Preferred citation"]', mods: 'http://www.loc.gov/mods/v3').text,
      identifier: context.output_hash['url_fulltext'],
      license: record.mods.xpath('//mods:accessCondition[@type="license"]', mods: 'http://www.loc.gov/mods/v3').text,
      name: context.output_hash['title_display'],
      description: context.output_hash['summary_search'],
      sameAs: "https://searchworks.stanford.edu/view/#{record.druid}",
      keywords: context.output_hash['subject_all_search'],
      includedInDataCatalog: {
        '@type': 'DataCatalog',
        'name': 'https://earthworks.stanford.edu'
      },
      distribution: [
        {
          '@type': 'DataDownload',
          encodingFormat: 'application/zip',
          contentUrl: "https://stacks.stanford.edu/file/druid:#{record.druid}/data.zip"
        }
      ]
    }
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
      case c.label
      when /phd/i
        accumulator << 'Thesis/Dissertation|Doctoral|Unspecified'
      when /master/i
        accumulator << 'Thesis/Dissertation|Master\'s|Unspecified'
      when /honor/i
        accumulator << 'Thesis/Dissertation|Bachelor\'s|Undergraduate honors thesis'
      when /capstone/i, /undergraduate/i
        accumulator << 'Thesis/Dissertation|Bachelor\'s|Unspecified'
      else
        accumulator << 'Thesis/Dissertation|Unspecified'
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
        post_text: ("(#{name.label.gsub(/:$/, '')})" if name.label.present?)
      }
    end
  end
end

to_field 'summary_display', mods_display(:abstract)

each_record do |record, context|
  $druid_title_cache[record.druid] = record.label if record.is_collection
end
