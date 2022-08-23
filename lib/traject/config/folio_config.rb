$LOAD_PATH << File.expand_path('../..', __dir__)

require 'traject'
require 'traject/macros/marc21_semantics'
require 'traject/readers/folio_reader'
require 'traject/writers/solr_better_json_writer'
require 'traject/common/marc_utils'
require 'traject/common/constants'
require 'call_numbers/lc'
require 'call_numbers/dewey'
require 'call_numbers/other'
require 'call_numbers/shelfkey'
require 'sirsi_holding'
require 'mhld_field'
require 'marc_links'
require 'i18n'
require 'honeybadger'
require 'utils'

I18n.available_locales = [:en]

settings do
  # Upstream siris_config will provide a default value; we need to override it if it wasn't provided
  if self['kafka.topic']
    require 'traject/readers/kafka_folio_reader'
    provide 'reader_class_name', 'Traject::KafkaFolioReader'
  elsif self['postgres.url']
    require 'traject/readers/folio_postgres_reader'
    provide 'reader_class_name', 'Traject::FolioPostgresReader'
  else
    provide 'reader_class_name', 'Traject::FolioReader'
  end

  provide 'folio.client', FolioClient.new(url: self['okapi.url'] || ENV['OKAPI_URL'], username: ENV['OKAPI_USER'], password: ENV['OKAPI_PASSWORD'])
end

##
# Skip records that have a suppressFromDiscovery field
each_record do |record, context|
  if record.record.dig('instance', 'suppressFromDiscovery')
    context.output_hash['id'] = [record.hrid.sub(/^a/, '')]
    context.skip!('Delete')
  end
end

load_config_file(File.expand_path('../sirsi_config.rb', __FILE__))


def call_number_for_holding(record, holding, context)
  context.clipboard[:call_number_for_holding] ||= {}
  context.clipboard[:call_number_for_holding][holding] ||= begin
    return OpenStruct.new(scheme: holding.call_number_type) if holding.is_on_order? || holding.is_in_process?

    serial = (context.output_hash['format_main_ssim'] || []).include?('Journal/Periodical')

    separate_browse_call_num = []
    if holding.call_number.to_s.empty? || holding.ignored_call_number?
      if record['086']
        last_086 = record.find_all { |f| f.tag == '086' }.last
        separate_browse_call_num << CallNumbers::Other.new(last_086['a'], scheme: last_086.indicator1 == '0' ? 'SUDOC' : 'OTHER')
      end

      Traject::MarcExtractor.cached('050ab:090ab', alternate_script: false).extract(record).each do |item_050|
        separate_browse_call_num << CallNumbers::LC.new(item_050, serial: serial) if SirsiHolding::CallNumber.new(item_050).valid_lc?
      end
    end

    return separate_browse_call_num.first if separate_browse_call_num.any?

    return OpenStruct.new(
      scheme: 'OTHER',
      call_number: holding.call_number.to_s,
      to_volume_sort: CallNumbers::ShelfkeyBase.pad_all_digits("other #{holding.call_number.to_s}")
    ) if holding.bad_lc_lane_call_number?
    return OpenStruct.new(scheme: holding.call_number_type) if holding.e_call_number?
    return OpenStruct.new(scheme: holding.call_number_type) if holding.ignored_call_number?

    calculated_call_number_type = case holding.call_number_type
                                  when 'LC'
                                    if holding.valid_lc?
                                      'LC'
                                    elsif holding.dewey?
                                      'DEWEY'
                                    else
                                      'OTHER'
                                    end
                                  when 'DEWEY'
                                    'DEWEY'
                                  else
                                    'OTHER'
                                  end

    case calculated_call_number_type
    when 'LC'
      CallNumbers::LC.new(holding.call_number.to_s, serial: serial)
    when 'DEWEY'
      CallNumbers::Dewey.new(holding.call_number.to_s, serial: serial)
    else
      non_skipped_or_ignored_holdings = context.clipboard[:non_skipped_or_ignored_holdings_by_library_location_call_number_type]

      call_numbers_in_location = (non_skipped_or_ignored_holdings[[holding.library, LOCATION_MAP[holding.home_location], holding.call_number_type]] || []).map(&:call_number).map(&:to_s)

      CallNumbers::Other.new(
        holding.call_number.to_s,
        longest_common_prefix: Utils.longest_common_prefix(*call_numbers_in_location),
        scheme: holding.call_number_type == 'LC' ? 'OTHER' : holding.call_number_type
      )
    end
  end
end

def holdings(record, context)
  context.clipboard[:holdings] ||= record.sirsi_holdings
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

to_field 'location_facet' do |record, accumulator, context|
  if holdings(record, context).any? { |holding| holding.home_location == 'CURRICULUM' }
    accumulator << 'Curriculum Collection'
  end

  if holdings(record, context).any? { |holding| holding.home_location =~ /^ARTLCK/ || holding.home_location == 'PAGE-AR' }
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
  accumulator << Date.parse(timestamp).to_time.utc.at_beginning_of_day.iso8601 if timestamp && !timestamp.include?('u')
end

# add folio to the collection list; searchworks has some dependencies on this value,
# so for now, we're just appending 'folio' to the list.
to_field 'collection', literal('folio')

# sirsi_config sets this to 'sirsi'; we need to remove that and set our own value:
to_field 'context_source_ssi' do |record, accumulator, context|
  context.output_hash['context_source_ssi'] = ['folio']
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
