$LOAD_PATH << File.expand_path('../..', __dir__)

require 'traject'
require 'traject/macros/marc21_semantics'
require 'traject/readers/folio_reader'
require 'traject/writers/solr_better_json_writer'
require 'traject/common/marc_utils'
require 'call_numbers/lc'
require 'call_numbers/dewey'
require 'call_numbers/other'
require 'call_numbers/shelfkey'
require 'sirsi_holding'
require 'i18n'
require 'honeybadger'
require 'utils'

I18n.available_locales = [:en]

extend Traject::Macros::Marc21
extend Traject::Macros::Marc21Semantics
extend Traject::SolrBetterJsonWriter::IndexerPatch
extend Traject::MarcUtils

Utils.logger = logger
indexer = self

ALPHABET = [*'a'..'z'].join('')
A_X = ALPHABET.slice(0, 24)
MAX_CODE_POINT = 0x10FFFF.chr(Encoding::UTF_8)
CJK_RANGE = /(\p{Han}|\p{Hangul}|\p{Hiragana}|\p{Katakana})/

settings do
  provide 'writer_class_name', 'Traject::SolrBetterJsonWriter'
  provide 'solr.url', ENV['SOLR_URL']
  provide 'processing_thread_pool', ENV['NUM_THREADS']
  provide 'reader_class_name', 'Traject::FolioReader'

  provide 'allow_duplicate_values', false
  provide 'solr_writer.commit_on_close', true
  provide 'mapping_rescue', (lambda do |context, e|
    Honeybadger.notify(e, context: { record: context.record_inspect, index_step: context.index_step.inspect })

    indexer.send(:default_mapping_rescue).call(context, e)
  end)

  provide 'solr_json_writer.http_client', HTTPClient.new.tap { |x| x.receive_timeout = 600 }
  provide 'solr_json_writer.skippable_exceptions', [HTTPClient::TimeoutError, StandardError]
end

# Change the XMLNS to match how solrmarc handles this
# Copied from sirsi_config.rb
class SolrMarcStyleFastXMLWriter < MARC::FastXMLWriter
  class << self
    def open_collection(use_ns)
      if use_ns
        %(<collection xmlns="http://www.loc.gov/MARC21/slim">).dup
      else
        '<collection>'.dup
      end
    end
  end
end

# Monkey-patch MarcExtractor in order to add logic to strip subfields before
# joining them, for parity with solrmarc.
# Copied from sirsi_config.rb
class Traject::MarcExtractor
  def collect_subfields(field, spec)
    subfields = field.subfields.collect do |subfield|
      subfield.value if spec.includes_subfield_code?(subfield.code)
    end.compact

    return subfields if subfields.empty? # empty array, just return it.

    subfields = [subfields.map(&:strip).join(options[:separator])] if options[:separator] && spec.joinable?

    subfields
  end
end

to_field 'id', extract_marc('001') do |_record, accumulator|
  accumulator.map! do |v|
    v.sub(/^a/, '')
  end
end

to_field 'hashed_id_ssi' do |_record, accumulator, context|
  next unless context.output_hash['id']

  accumulator << Digest::MD5.hexdigest(context.output_hash['id'].first)
end

to_field 'marcxml' do |record, accumulator|
  accumulator << (SolrMarcStyleFastXMLWriter.single_record_document(record.marc_record, include_namespace: true) + "\n")
end

to_field 'all_search' do |record, accumulator|
  keep_fields = %w[024 027 028 033 905 908 920 986 979]
  result = []
  record.each do |field|
    next unless (100..899).cover?(field.tag.to_i) || keep_fields.include?(field.tag)

    subfield_values = field.subfields.collect(&:value)
    next unless subfield_values.length > 0

    result << subfield_values.join(' ')
  end
  accumulator << result.join(' ') if result.any?
end

to_field 'vern_all_search' do |record, accumulator|
  keep_fields = %w[880]
  result = []
  record.each do |field|
    next unless  keep_fields.include?(field.tag)

    subfield_values = field.subfields
                           .select { |sf| ALPHABET.include? sf.code }
                           .collect(&:value)

    next unless subfield_values.length > 0

    result << subfield_values.join(' ')
  end
  accumulator << result.join(' ') if result.any?
end

# Title Search Fields
to_field 'title_245a_search', extract_marc_and_prefer_non_alternate_scripts('245a', first: true)
to_field 'vern_title_245a_search', extract_marc('245aa', first: true, alternate_script: :only)
to_field 'title_245_search', extract_marc_and_prefer_non_alternate_scripts('245abfgknps', first: true)
to_field 'vern_title_245_search', extract_marc('245abfgknps', first: true, alternate_script: :only)
to_field 'title_uniform_search', extract_marc('130adfgklmnoprst:240adfgklmnoprs', first: true, alternate_script: false)
to_field 'vern_title_uniform_search',
         extract_marc('130adfgklmnoprst:240adfgklmnoprs', first: true, alternate_script: :only)
to_field 'title_variant_search',
         extract_marc('210ab:222ab:242abnp:243adfgklmnoprs:246abfgnp:247abfgnp', alternate_script: false)
to_field 'vern_title_variant_search',
         extract_marc('210ab:222ab:242abnp:243adfgklmnoprs:246abfgnp:247abfgnp', alternate_script: :only)
to_field 'title_related_search',
         extract_marc(
           '505t:700fgklmnoprst:710dfgklmnoprst:711fgklnpst:730adfgklmnoprst:740anp:760st:762st:765st:767st:770st:772st:773st:774st:775st:776st:777st:780st:785st:786st:787st:796fgklmnoprst:797dfgklmnoprst:798fgklnpst:799adfgklmnoprst', alternate_script: false
         )
to_field 'vern_title_related_search',
         extract_marc(
           '505tt:700fgklmnoprst:710dfgklmnoprst:711fgklnpst:730adfgklmnoprst:740anp:760st:762st:765st:767st:770st:772st:773st:774st:775st:776st:777st:780st:785st:786st:787st:796fgklmnoprst:797dfgklmnoprst:798fgklnpst:799adfgklmnoprst', alternate_script: :only
         )
# Title Display Fields
to_field 'title_245a_display', extract_marc('245a', first: true, alternate_script: false) do |_record, accumulator|
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'vern_title_245a_display',
         extract_marc('245aa', first: true, alternate_script: :only) do |_record, accumulator|
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'title_245c_display', extract_marc('245c', first: true, alternate_script: false) do |_record, accumulator|
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'vern_title_245c_display',
         extract_marc('245cc', first: true, alternate_script: :only) do |_record, accumulator|
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'title_display',
         extract_marc('245abdefghijklmnopqrstuvwxyz', first: true, alternate_script: false) do |_record, accumulator|
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'vern_title_display',
         extract_marc('245abdefghijklmnopqrstuvwxyz', first: true, alternate_script: :only) do |_record, accumulator|
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'title_full_display', extract_marc("245#{ALPHABET}", first: true, alternate_script: false)
to_field 'vern_title_full_display', extract_marc("245#{ALPHABET}", first: true, alternate_script: :only)
to_field 'title_uniform_display', extract_marc(%w[130 240].map do |c|
  "#{c}#{ALPHABET}"
end.join(':'), first: true, alternate_script: false)
# # ? no longer will use title_uniform_display due to author-title searching needs ? 2010-11
# TODO: Remove looks like SearchWorks is not using, confirm relevancy changes
to_field 'vern_title_uniform_display', extract_marc(%w[130 240].map do |c|
  "#{c}#{ALPHABET}"
end.join(':'), first: true, alternate_script: :only)
# # Title Sort Field
to_field 'title_sort' do |record, accumulator|
  result = []
  result << extract_sortable_title("130#{ALPHABET}", record)
  result << extract_sortable_title('245abdefghijklmnopqrstuvwxyz', record)
  str = result.join(' ').strip
  accumulator << str unless str.empty?
end

def library_for_code(code)
  { 'ARS' => 'ARS', 'ART' => 'ART', 'BUS' => 'BUSINESS', 'CLA' => 'CLASSICS', 'EAR' => 'EARTH-SCI', 'EAL' => 'EAST-ASIA', 'EDU' => 'EDUCATION', 'ENG' => 'ENG', 'GRE' => 'GREEN', 'HILA' => 'HOOVER', 'MAR' => 'HOPKINS', 'LANE' => 'LANE', 'LAW' => 'LAW', 'MEDIA' => 'MEDIA-MTXT', 'MUS' => 'MUSIC', 'RUM' => 'RUMSEYMAP', 'SAL' => 'SAL', 'SCI' => 'SCIENCE', 'SPEC' => 'SPEC-COLL', 'TAN' => 'TANNER' }.fetch(
    code, code
  )
end

def holdings(record, context)
  context.clipboard[:holdings] ||= record.items.map do |item|
    SirsiHolding.new(
      call_number: item.dig('effectiveCallNumberComponents', 'callNumber'),
      current_location: item.dig('effectiveLocation', 'code').split('-', 2).last,
      home_location: item.dig('permanentLocation', 'code').split('-', 2).last,
      library: library_for_code(item.dig('permanentLocation', 'code').split('-', 2).first),
      scheme: item.dig('effectiveCallNumberComponents', 'typeId'),
      type: item.dig('materialType', 'name'),
      barcode: item['barcode'],
      tag: item
    )
  end
end

def call_number_for_holding(_record, _holding, _context)
  OpenStruct.new({
                   scheme: ''
                 })
end

LOCATION_MAP = Traject::TranslationMap.new('location_map')

each_record do |record, context|
  non_skipped_or_ignored_holdings = []

  holdings(record, context).each do |holding|
    next if holding.skipped? || holding.ignored_call_number?

    non_skipped_or_ignored_holdings << holding
  end

  # Group by library, home location, and call numbe type
  result = non_skipped_or_ignored_holdings = non_skipped_or_ignored_holdings.group_by do |holding|
    [holding.library, LOCATION_MAP[holding.home_location], holding.call_number_type]
  end

  context.clipboard[:non_skipped_or_ignored_holdings_by_library_location_call_number_type] = result
end

to_field 'item_display' do |record, accumulator, context|
  holdings(record, context).each do |holding|
    next if holding.skipped?

    non_skipped_or_ignored_holdings = context.clipboard[:non_skipped_or_ignored_holdings_by_library_location_call_number_type]

    call_number = holding.call_number
    call_number_object = call_number_for_holding(record, holding, context)
    stuff_in_the_same_library = Array(non_skipped_or_ignored_holdings[[holding.library,
                                                                       LOCATION_MAP[holding.home_location], holding.call_number_type]])

    if call_number_object
      scheme = call_number_object.scheme.upcase
      # if it's a shelved-by location, use a totally different way to get the callnumber
      if holding.shelved_by_location?
        lopped_call_number = if [holding.home_location, holding.current_location].include? 'SHELBYSER'
                               'Shelved by Series title'
                             else
                               'Shelved by title'
                             end

        unless holding.ignored_call_number?
          enumeration = holding.call_number.to_s[call_number_object.lopped.length..-1].strip
        end
        shelfkey = lopped_call_number.downcase
        reverse_shelfkey = CallNumbers::ShelfkeyBase.reverse(shelfkey)

        call_number = [lopped_call_number, enumeration].compact.join(' ') unless holding.e_call_number?
        volume_sort = [lopped_call_number,
                       (if enumeration
                          CallNumbers::ShelfkeyBase.reverse(CallNumbers::ShelfkeyBase.pad_all_digits(enumeration)).ljust(
                            50, '~'
                          )
                        end)].compact.join(' ').downcase
      # if there's only one item in a library/home_location/call_number_type, then we use the non-lopped versions of stuff
      elsif stuff_in_the_same_library.length <= 1
        shelfkey = call_number_object.to_shelfkey
        volume_sort = call_number_object.to_volume_sort
        reverse_shelfkey = call_number_object.to_reverse_shelfkey
        lopped_call_number = call_number_object.call_number
      else
        # there's more than one item in the library/home_location/call_number_type, so we lop
        shelfkey = call_number_object.to_lopped_shelfkey == call_number_object.to_shelfkey ? call_number_object.to_shelfkey : "#{call_number_object.to_lopped_shelfkey} ..."
        volume_sort = call_number_object.to_volume_sort
        reverse_shelfkey = call_number_object.to_lopped_reverse_shelfkey
        lopped_call_number = call_number_object.lopped == holding.call_number.to_s ? holding.call_number.to_s : "#{call_number_object.lopped} ..."

        # if we lopped the shelfkey, or if there's other stuff in the same library whose shelfkey will be lopped to this holding's shelfkey, we need to add ellipses.
        if call_number_object.lopped == holding.call_number.to_s && stuff_in_the_same_library.reject do |x|
                                                                      x.call_number.to_s == holding.call_number.to_s
                                                                    end.select do |x|
             call_number_for_holding(record, x,
                                     context).lopped == call_number_object.lopped
           end.any?
          lopped_call_number += ' ...'
          shelfkey += ' ...'
        end
      end
    else
      scheme = ''
      shelfkey = ''
      volume_sort = ''
      reverse_shelfkey = ''
      lopped_call_number = holding.call_number.to_s
    end

    current_location = holding.current_location
    if holding.is_on_order? && holding.current_location && !holding.current_location.empty? && holding.home_location != 'ON-ORDER' && holding.home_location != 'INPROCESS'
      current_location = 'ON-ORDER'
    end

    accumulator << [
      holding.barcode,
      holding.library,
      holding.home_location,
      current_location,
      holding.type,
      (lopped_call_number unless holding.ignored_call_number? && !holding.shelved_by_location?),
      (shelfkey unless holding.lost_or_missing?),
      (reverse_shelfkey.ljust(50, '~') if reverse_shelfkey && !reverse_shelfkey.empty? && !holding.lost_or_missing?),
      (unless holding.ignored_call_number? && !holding.shelved_by_location?
         call_number
       end) || (if holding.e_call_number? && call_number.to_s != SirsiHolding::ECALLNUM && !call_number_object.call_number
                  call_number
                end),
      (volume_sort unless holding.ignored_call_number? && !holding.shelved_by_location?),
      (holding.tag['o'] if holding.tag['o'] && holding.tag['o'].upcase.start_with?('.PUBLIC.')),
      scheme
    ].join(' -|- ')
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

to_field 'uuid_ssi' do |record, accumulator|
  accumulator << record.instance_id
end

to_field 'marc_json_struct' do |record, accumulator|
  accumulator << record.marc_record.to_json
end

to_field 'folio_json_struct' do |record, accumulator|
  accumulator << record.record.to_json
end

to_field 'holdings_json_struct' do |record, accumulator|
  accumulator << record.holdings.to_json
end

to_field 'items_json_struct' do |record, accumulator|
  accumulator << record.items.to_json
end
