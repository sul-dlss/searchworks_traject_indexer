$LOAD_PATH << File.expand_path('../..', __dir__)

require 'traject'
require 'traject/macros/marc21_semantics'
require 'traject/readers/folio_reader'
require 'traject/readers/kafka_folio_reader'
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

instance_eval(IO.read(File.expand_path('../sirsi_config.rb', __FILE__)))

settings do
  provide 'writer_class_name', 'Traject::SolrBetterJsonWriter'
  provide 'solr.url', ENV['SOLR_URL']
  provide 'processing_thread_pool', ENV['NUM_THREADS']
  if ENV['KAFKA_TOPIC']
    provide "reader_class_name", "Traject::KafkaFolioReader"
    kafka = Kafka.new(ENV.fetch('KAFKA', 'localhost:9092').split(','))
    consumer = kafka.consumer(group_id: ENV.fetch('KAFKA_CONSUMER_GROUP_ID', "traject_#{ENV['KAFKA_TOPIC']}"), fetcher_max_queue_size: 15)
    consumer.subscribe(ENV['KAFKA_TOPIC'])
    provide 'kafka.consumer', consumer
  else
    provide "reader_class_name", "Traject::FolioReader"
  end

  provide 'allow_duplicate_values', false
  provide 'skip_empty_item_display', ENV['SKIP_EMPTY_ITEM_DISPLAY'].to_i
  provide 'solr_writer.commit_on_close', true
  provide 'mapping_rescue', (lambda do |context, e|
    Honeybadger.notify(e, context: { record: context.record_inspect, index_step: context.index_step.inspect })

    indexer.send(:default_mapping_rescue).call(context, e)
  end)

  provide 'solr_json_writer.http_client', HTTPClient.new.tap { |x| x.receive_timeout = 600 }
  provide 'solr_json_writer.skippable_exceptions', [HTTPClient::TimeoutError, StandardError]
  provide 'folio.client', FolioClient.new(url: ENV['OKAPI_URL'], username: ENV['OKAPI_USER'], password: ENV['OKAPI_PASSWORD'])
end

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
  context.clipboard[:holdings] ||= record.items.map do |item|
    library_code, home_location_code = item.dig('permanentLocation', 'code').split('-', 2)
    current_location = item.dig('effectiveLocation', 'code').split('-', 2).last
    SirsiHolding.new(
      call_number: [item.dig('effectiveCallNumberComponents', 'callNumber'), item['volume']].compact.join(' '),
      current_location: (current_location unless current_location == home_location_code),
      home_location: home_location_code,
      library: library_for_code(item.dig('permanentLocation', 'code').split('-', 2).first),
      scheme: call_number_type_map(record.call_number_type(item.dig('effectiveCallNumberComponents', 'typeId')).dig('name')),
      type: item.dig('materialType', 'name'),
      barcode: item['barcode'],
      # TODO: not implementing public note (was 999 subfield o) currently
      tag: item
    )
  end
end

def library_for_code(code)
  { 'ARS' => 'ARS', 'ART' => 'ART', 'BUS' => 'BUSINESS', 'CLA' => 'CLASSICS', 'EAR' => 'EARTH-SCI', 'EAL' => 'EAST-ASIA', 'EDU' => 'EDUCATION', 'ENG' => 'ENG', 'GRE' => 'GREEN', 'HILA' => 'HOOVER', 'MAR' => 'HOPKINS', 'LANE' => 'LANE', 'LAW' => 'LAW', 'MEDIA' => 'MEDIA-MTXT', 'MUS' => 'MUSIC', 'RUM' => 'RUMSEYMAP', 'SAL' => 'SAL', 'SCI' => 'SCIENCE', 'SPEC' => 'SPEC-COLL', 'TAN' => 'TANNER' }.fetch(
    code, code
  )
end

def call_number_type_map(name)
  case name
  when /dewey/i
    'DEWEY'
  when /congress/i, /LC/i
    'LC'
  when /superintendent/i
    'SUDOC'
  when /title/i, /shelving/i
    'ALPHANUM'
  else
    'OTHER'
  end
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

to_field 'date_cataloged' do |record, accumulator|
  # solr needs datetimes in UTC, so we parse and reformat them from FOLIO
  # TODO: is this the right place to get this from? use instanceRecord or holdingsRecord instead?
  # when are these timestamps updated in FOLIO?
  timestamp = record.record.dig('metadata', 'createdDate')
  accumulator << Time.iso8601(timestamp).utc.iso8601 if timestamp
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

to_field 'marc_json_struct' do |record, accumulator|
  accumulator << JSON.generate(record.marc_record)
end

to_field 'folio_json_struct' do |record, accumulator|
  accumulator << JSON.generate(record.record)
end

to_field 'holdings_json_struct' do |record, accumulator|
  accumulator << JSON.generate(record.holdings)
end

to_field 'items_json_struct' do |record, accumulator|
  accumulator << JSON.generate(record.items)
end
