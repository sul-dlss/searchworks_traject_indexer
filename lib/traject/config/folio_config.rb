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

to_field 'uniform_title_display_struct' do |record, accumulator|
  next unless record['240'] || record['130']

  uniform_title = record['130'] || record['240']
  pre_text = []
  link_text = []
  extra_text = []
  end_link = false
  uniform_title.each do |sub_field|
    next if Constants::EXCLUDE_FIELDS.include?(sub_field.code)
    if !end_link && sub_field.value.strip =~ /[\.|;]$/ && sub_field.code != 'h'
      link_text << sub_field.value
      end_link = true
    elsif end_link || sub_field.code == 'h'
      extra_text << sub_field.value
    elsif sub_field.code == 'i' # assumes $i is at beginning
      pre_text << sub_field.value.gsub(/\s*\(.+\)/, '')
    else
      link_text << sub_field.value
    end
  end

  author = []
  unless record['730']
    auth_field = record['100'] || record['110'] || record['111']
    author = auth_field.map do |sub_field|
      next if (Constants::EXCLUDE_FIELDS + %w(4 e)).include?(sub_field.code)
      sub_field.value
    end.compact if auth_field
  end

  vern = get_marc_vernacular(record, uniform_title)

  accumulator << {
    label: 'Uniform Title',
    unmatched_vernacular: nil,
    fields: [
      {
        uniform_title_tag: uniform_title.tag,
        field: {
          pre_text: pre_text.join(' '),
          link_text: link_text.join(' '),
          author: author.join(' '),
          post_text: extra_text.join(' ')
        },
        vernacular: {
          vern: vern
        },
        authorities: uniform_title.subfields.select { |x| x.code == '0' }.map(&:value),
        rwo: uniform_title.subfields.select { |x| x.code == '1' }.map(&:value)
      }
    ]
  }
end

to_field 'uniform_title_authorities_ssim', extract_marc('1300:1301:2400:2401')

# Series Search Fields
to_field 'series_search', extract_marc("440anpv:490av", alternate_script: false)

to_field 'series_search', extract_marc("800#{A_X}:810#{A_X}:811#{A_X}:830#{A_X}", alternate_script: false) do |record, accumulator|
  accumulator.map!(&method(:trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff))
end

to_field 'vern_series_search', extract_marc("440anpv:490av:800#{A_X}:810#{A_X}:811#{A_X}:830#{A_X}", alternate_script: :only)
to_field 'series_exact_search', extract_marc('830a', alternate_script: false)

# # Author Title Search Fields
to_field 'author_title_search' do |record, accumulator|
  onexx = trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff(Traject::MarcExtractor.cached('100abcdfghijklmnopqrstuvwxyz:110abcdfghijklmnopqrstuvwxyz:111abcdefghjklmnopqrstuvwxyz', alternate_script: false).extract(record).first)

  twoxx = trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff(Traject::MarcExtractor.cached('240' + ALPHABET, alternate_script: false).extract(record).first) if record['240']
  twoxx ||= Traject::MarcExtractor.cached('245aa', alternate_script: false).extract(record).first if record['245']
  twoxx ||= 'null'

  accumulator << [onexx, twoxx].compact.reject(&:empty?).map(&:strip).join(' ') if onexx
end

to_field 'author_title_search' do |record, accumulator|
  onexx = Traject::MarcExtractor.cached('100abcdfghijklmnopqrstuvwxyz:110abcdfghijklmnopqrstuvwxyz:111abcdefghjklmnopqrstuvwxyz', alternate_script: :only).extract(record).first

  twoxx = Traject::MarcExtractor.cached('240' + ALPHABET, alternate_script: :only).extract(record).first
  twoxx ||= Traject::MarcExtractor.cached('245aa', alternate_script: :only).extract(record).first
  accumulator << [onexx, twoxx].compact.reject(&:empty?).map(&:strip).join(' ') if onexx && twoxx
end

to_field 'author_title_search' do |record, accumulator|
  Traject::MarcExtractor.cached('700abcdfghjklmnopqrstuvwyz:710abcdfghjklmnopqrstuvwyz:711abcdefghjklmnopqrstuvwyz', alternate_script: false).collect_matching_lines(record)  do |field, spec, extractor|
    accumulator.concat extractor.collect_subfields(field, spec) if field['t']
  end
end

to_field 'author_title_search' do |record, accumulator|
  Traject::MarcExtractor.cached('700abcdfghjklmnopqrstuvwyz:710abcdfghjklmnopqrstuvwyz:711abcdefghjklmnopqrstuvwyz', alternate_script: :only).collect_matching_lines(record)  do |field, spec, extractor|
    accumulator.concat extractor.collect_subfields(field, spec) if field['t']
  end
end

to_field 'author_title_search' do |record, accumulator|
  Traject::MarcExtractor.cached('800abcdfghijklmnopqrstuyz:810abcdfghijklmnopqrstuyz:811abcdfghijklmnopqrstuyz').collect_matching_lines(record)  do |field, spec, extractor|
    accumulator.concat extractor.collect_subfields(field, spec) if field['t']
  end
end

# # Author Search Fields
# # IFF relevancy of author search needs improvement, unstemmed flavors for author search
# #   (keep using stemmed version for everything search to match stemmed query)
to_field 'author_1xx_search', extract_marc('100abcdgjqu:110abcdgnu:111acdegjnqu', first: true, alternate_script: false)
to_field 'vern_author_1xx_search', extract_marc('100abcdgjqu:110abcdgnu:111acdegjnqu', first: true, alternate_script: :only)
to_field 'author_7xx_search', extract_marc('700abcdgjqu:720ae:796abcdgjqu:710abcdgnu:797abcdgnu:711acdejngqu:798acdegjnqu', alternate_script: false)
to_field 'vern_author_7xx_search', extract_marc('700abcdgjqu:720ae:796abcdgjqu:710abcdgnu:797abcdgnu:711acdegjnqu:798acdegjnqu', alternate_script: :only)
to_field 'author_8xx_search', extract_marc('800abcdegjqu:810abcdegnu:811acdegjnqu', alternate_script: false)
to_field 'vern_author_8xx_search', extract_marc('800abcdegjqu:810abcdegnu:811acdegjnqu', alternate_script: :only)
# # Author Facet Fields
to_field 'author_person_facet', extract_marc('100abcdq:700abcdq', alternate_script: false) do |record, accumulator|
  accumulator.map! { |v| v.gsub(/([\)-])[\\,;:]\.?$/, '\1')}
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'author_other_facet', extract_marc('110abcdn:111acdn:710abcdn:711acdn', alternate_script: false) do |record, accumulator|
  accumulator.map! { |v| v.gsub(/(\))\.?$/, '\1')}
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.map!(&method(:trim_punctuation_custom))
end
# # Author Display Fields
to_field 'author_person_display', extract_marc('100abcdq', first: true, alternate_script: false) do |record, accumulator|
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'vern_author_person_display', extract_marc('100abcdq', first: true, alternate_script: :only) do |record, accumulator|
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'author_person_full_display', extract_marc("100#{ALPHABET}", first: true, alternate_script: false)
to_field 'vern_author_person_full_display', extract_marc("100#{ALPHABET}", first: true, alternate_script: :only)
to_field 'author_corp_display', extract_marc("110#{ALPHABET}", first: true, alternate_script: false)
to_field 'vern_author_corp_display', extract_marc("110#{ALPHABET}", first: true, alternate_script: :only)
to_field 'author_meeting_display', extract_marc("111#{ALPHABET}", first: true, alternate_script: false)
to_field 'vern_author_meeting_display', extract_marc("111#{ALPHABET}", first: true, alternate_script: :only)
# # Author Sort Field
to_field 'author_sort' do |record, accumulator|
  accumulator << extract_sortable_author("100#{ALPHABET.delete('e')}:110#{ALPHABET.delete('e')}:111#{ALPHABET.delete('j')}",
                                         "240#{ALPHABET}:245#{ALPHABET.delete('c')}",
                                         record)
end

to_field 'author_struct' do |record, accumulator|
  struct = {}
  struct[:creator] = linked_author_struct(record, '100')
  struct[:corporate_author] = linked_author_struct(record, '110')
  struct[:meeting] = linked_author_struct(record, '111')
  struct[:contributors] = linked_contributors_struct(record)
  struct.reject! { |_k, v| v.empty? }

  accumulator << struct unless struct.empty?
end

to_field 'works_struct' do |record, accumulator|
  struct = {
    included: works_struct(record, '700:710:711:730:740', indicator2: '2'),
    related: works_struct(record, '700:710:711:730:740', indicator2: nil),
  }

  accumulator << struct unless struct.empty?
end

to_field 'author_authorities_ssim', extract_marc('1001:1000:1100:1101:1110:1111:7000:7001:7100:7101:7110:7111:7200:7201:7300:7301:7400:7401')

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
      tag: item
    )
  end
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
# - How should we handle item statuses? "at the bindery", "lost"?
# - does effectiveShelvingOrder replace our shelfkeys (and get rid of weird lopping code) ? help with shelve-by-title enumeration?

to_field 'uuid_ssi' do |record, accumulator|
  accumulator << record.instance_id
end

to_field 'marc_json_struct' do |record, accumulator|
  accumulator << record.marc_record
end

to_field 'folio_json_struct' do |record, accumulator|
  accumulator << record.record
end

to_field 'holdings_json_struct' do |record, accumulator|
  accumulator << record.holdings
end

to_field 'items_json_struct' do |record, accumulator|
  accumulator << record.items
end


## JSONify the entire record as a postprocessing step
each_record do |record, context|
  context.output_hash.select { |k, _v| k =~ /_struct$/ }.each do |k, v|
    context.output_hash[k] = Array(v).map { |x| JSON.generate(x) }
  end
end
