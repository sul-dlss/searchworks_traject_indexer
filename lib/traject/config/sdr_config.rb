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
  provide 'skip_if_catkey', !!ENV.fetch('SKIP_IF_CATKEY', true)
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

##
# Skip records that probably have an equivalent MARC record
each_record do |record, context|
  context.skip!('Item has a catkey') if context.settings['skip_if_catkey'] && record.catkey
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

# deprecated pub_date Solr field - use pub_year_isi for sort key; pub_year_ss for display field
#   can remove after other fields are populated for all indexing data (i.e. solrmarc, crez) and app code is changed
to_field 'pub_date', stanford_mods(:pub_year_display_str)
to_field 'pub_year_ss', stanford_mods(:pub_year_display_str)

# TODO: need better implementation for date slider in stanford-mods (e.g. multiple years when warranted)
to_field 'pub_year_tisim', stanford_mods(:pub_year_int)

to_field 'creation_year_isi' do |record, accumulator|
  accumulator << record.stanford_mods.year_int(record.stanford_mods.date_created_elements)
end
to_field 'publication_year_isi' do |record, accumulator|
  accumulator << record.stanford_mods.year_int(record.stanford_mods.date_issued_elements)
end

to_field 'format_main_ssim', stanford_mods(:format_main)
to_field 'format', stanford_mods(:format) # deprecated; for backwards compatibility
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

each_record do |record, context|
  $druid_title_cache[record.druid] = record.label if record.is_collection
end
