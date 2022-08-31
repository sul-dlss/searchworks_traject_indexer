# frozen_string_literal: true

require 'traject'
require 'traject/macros/marc21_semantics'
require 'i18n'
require 'active_support'
require 'active_support/core_ext/time'

I18n.available_locales = [:en]

settings do
  # Upstream siris_config will provide a default value; we need to override it if it wasn't provided
  if self['kafka.topic']
    require './lib/traject/readers/kafka_folio_reader'
    provide 'reader_class_name', 'Traject::KafkaFolioReader'
  elsif self['postgres.url']
    require './lib/traject/readers/folio_postgres_reader'
    provide 'reader_class_name', 'Traject::FolioPostgresReader'
  elsif self['reader_class_name'] == 'Traject::FolioJsonReader'
    require './lib/traject/readers/folio_json_reader'
  else
    provide 'reader_class_name', 'Traject::FolioReader'
    provide 'folio.client', FolioClient.new(url: self['okapi.url'] || ENV.fetch('OKAPI_URL', nil))
  end
end

##
# Skip records that have a suppressFromDiscovery field
each_record do |record, context|
  if record.record.dig('instance', 'suppressFromDiscovery')
    context.output_hash['id'] = [record.hrid.sub(/^a/, '')]
    context.skip!('Delete')
  end
end

# Disable Sirsi reserves lookup from file in favor of FOLIO data
def reserves_lookup = {}

load_config_file(File.expand_path('sirsi_config.rb', __dir__))

def holdings(record, context)
  context.clipboard[:holdings] ||= record.sirsi_holdings.concat(record.eresource_holdings)
end

## FOLIO diverging implementations

# * INDEX-89 - Add video physical formats
to_field 'format_physical_ssim' do |record, accumulator, context|
  holdings(record, context).each do |holding|
    call_number = holding.call_number.to_s

    accumulator << 'Blu-ray' if call_number =~ /BLU-RAY/
    accumulator << 'Videocassette (VHS)' if call_number =~ Regexp.union(/ZVC/, /ARTVC/, /MVC/)
    accumulator << 'DVD' if call_number =~ Regexp.union(/ZDVD/, /ARTDVD/, /MDVD/, /ADVD/)
    accumulator << 'Videocassette' if call_number =~ /AVC/
    accumulator << 'Laser disc' if call_number =~ Regexp.union(/ZVD/, /MVD/)
  end
end

to_field 'mhld_display' do |record, accumulator, _context|
  record.mhld.each { |holding| accumulator << holding }
end

to_field 'location_facet' do |record, accumulator, context|
  if holdings(record, context).any? { |holding| holding.home_location == 'CURRICULUM' }
    accumulator << 'Curriculum Collection'
  end

  if holdings(record, context).any? do |holding|
       holding.home_location =~ /^ARTLCK/ || holding.home_location == 'PAGE-AR'
     end
    accumulator << 'Art Locked Stacks'
  end
end

to_field 'barcode_search' do |record, accumulator, context|
  context.output_hash['barcode_search'] = []

  holdings(record, context).each do |holding|
    accumulator << holding.barcode
  end
end

# guard against dates with 'u' coming out of MARC 008 fields
to_field 'date_cataloged' do |record, accumulator|
  timestamp = record.instance['catalogedDate']
  accumulator << Time.parse(timestamp).utc.at_beginning_of_day.iso8601 if timestamp =~ /\d{4}-\d{2}-\d{2}/
end

# add folio to the collection list; searchworks has some dependencies on this value,
# so for now, we're just appending 'folio' to the list.
to_field 'collection', literal('folio')

# sirsi_config sets this to 'sirsi'; we need to remove that and set our own value:
to_field 'context_source_ssi' do |_record, _accumulator, context|
  context.output_hash['context_source_ssi'] = ['folio']
end

to_field 'crez_instructor_search' do |record, _accumulator, context|
  context.output_hash['crez_instructor_search'] = record.courses.flat_map { |course| course[:instructors] }.compact.uniq
end

to_field 'crez_course_name_search' do |record, _accumulator, context|
  context.output_hash['crez_course_name_search'] = record.courses.map { |course| course[:course_name] }.compact.uniq
end

to_field 'crez_course_id_search' do |record, _accumulator, context|
  context.output_hash['crez_course_id_search'] = record.courses.map { |course| course[:course_id] }.compact.uniq
end

# TODO: included for parity; refactor SW to use courses_json_struct instead
to_field 'crez_course_info' do |record, _accumulator, context|
  context.output_hash['crez_course_info'] = record.courses.flat_map do |course|
    [course[:course_id]].product(course[:instructors]).map do |course_id, instructor|
      [course_id, course[:course_name], instructor].join(' -|- ')
    end
  end
end

## FOLIO specific fields

## QUESTIONS / ISSUES
# - change hashed_id to use uuid_ssi, since it's already a hash of some other fields?
# - use marc JSON (marc_json_struct) instead of marcxml?
# - what's in the 9XX fields set as keep_fields for all_search coming out of FOLIO?
# - why did we subclass MARC::FastXMLWriter and is the behavior in SolrMarcStyleFastXMLWriter still required?
# - is "materialType" the correct field for the item type in FOLIO?
# - URLs will be in the holdings record instead of the in 856
# - How should we handle item statuses? "at the bindery", "lost"?
# - does effectiveShelvingOrder replace our shelfkeys (and get rid of weird lopping code) ? help with shelve-by-title enumeration?

to_field 'uuid_ssi' do |record, accumulator|
  accumulator << record.instance_id
end

to_field 'folio_json_struct' do |record, accumulator|
  accumulator << JSON.generate(record.as_json.except('source_record', 'holdings', 'items'))
end

to_field 'holdings_json_struct' do |record, accumulator|
  accumulator << JSON.generate({
                                 holdings: record.holdings,
                                 items: record.items
                               })
end

to_field 'courses_json_struct' do |record, accumulator|
  accumulator << JSON.generate(record.courses)
end

to_field 'bound_with_parents_struct' do |record, accumulator|
  accumulator << record.bound_with_parents.to_json
end
