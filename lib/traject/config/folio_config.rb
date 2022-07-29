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

#
# # Subject Search Fields
# #  should these be split into more separate fields?  Could change relevancy if match is in field with fewer terms
to_field "topic_search", extract_marc("650abcdefghijklmnopqrstuw:653abcdefghijklmnopqrstuw:654abcdefghijklmnopqrstuw:690abcdefghijklmnopqrstuw", alternate_script: false) do |record, accumulator|
  accumulator.reject! { |v| v.start_with?('nomesh') }

  # FIXME: no 999s in FOLIO records
  if record['999'] && record['999']['m'] == 'LANE-MED'
    arr = []
    extract_marc('655a').call(record, arr, nil)
    accumulator.reject! { |v| arr.include? v }
  end
end

to_field "vern_topic_search", extract_marc("650abcdefghijklmnopqrstuw:653abcdefghijklmnopqrstuw:654abcdefghijklmnopqrstuw:690abcdefghijklmnopqrstuw", alternate_script: :only)
to_field "topic_subx_search", extract_marc("600x:610x:611x:630x:647x:650x:651x:655x:656x:657x:690x:691x:696x:697x:698x:699x", alternate_script: false)
to_field "vern_topic_subx_search", extract_marc("600xx:610xx:611xx:630xx:647xx:650xx:651xx:655xx:656xx:657xx:690xx:691xx:696xx:697xx:698xx:699xx", alternate_script: :only)
to_field "geographic_search", extract_marc("651abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw", alternate_script: false)
to_field "vern_geographic_search", extract_marc("651abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw", alternate_script: :only)
to_field "geographic_subz_search", extract_marc("600z:610z:630z:647z:650z:651z:654z:655z:656z:657z:690z:691z:696z:697z:698z:699z", alternate_script: false)

to_field "vern_geographic_subz_search", extract_marc("600zz:610zz:630zz:647zz:650zz:651zz:654zz:655zz:656zz:657zz:690zz:691zz:696zz:697zz:698zz:699zz", alternate_script: :only)
to_field "subject_other_search", extract_marc(%w(600 610 611 630 647 655 656 657 658 696 697 698 699).map { |c| "#{c}abcdefghijklmnopqrstuw"}.join(':'), alternate_script: false) do |record, accumulator|
  accumulator.reject! { |v| v.start_with?('nomesh') }

  # FIXME: no 999s in FOLIO records
  if record['999'] && record['999']['m'] == 'LANE-MED'
    arr = []
    extract_marc('655a').call(record, arr, nil)
    accumulator.reject! { |v| arr.include? v }
  end
end
to_field "vern_subject_other_search", extract_marc(%w(600 610 611 630 647 655 656 657 658 696 697 698 699).map { |c| "#{c}abcdefghijklmnopqrstuw"}.join(':'), alternate_script: :only)
to_field "subject_other_subvy_search", extract_marc(%w(600 610 611 630 647 650 651 654 655 656 657 658 690 691 696 697 698 699).map { |c| "#{c}vy"}.join(':'), alternate_script: false)
to_field "vern_subject_other_subvy_search", extract_marc(%w(600 610 611 630 647 650 651 654 655 656 657 658 690 691 696 697 698 699).map { |c| "#{c}vy"}.join(':'), alternate_script: :only)
to_field "subject_all_search", extract_marc(%w(600 610 611 630 647 648 650 651 652 653 654 655 656 657 658 662 690 691 696 697 698 699).map { |c| "#{c}#{ALPHABET}" }.join(':'), alternate_script: false)
to_field "vern_subject_all_search", extract_marc(%w(600 610 611 630 647 648 650 651 652 653 654 655 656 657 658 662 690 691 696 697 698 699).map { |c| "#{c}#{ALPHABET}"}.join(':'), alternate_script: :only)

# Subject Facet Fields
to_field "topic_facet", extract_marc("600abcdq:600t:610ab:610t:630a:630t:650a", alternate_script: false) do |record, accumulator|
  accumulator.map! { |v| trim_punctuation_custom(v, /([\p{L}\p{N}]{4}|[A-Za-z]{3}|[\)])\. *\Z/) }
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.reject! { |v| v.start_with?('nomesh') }
end

to_field "geographic_facet", extract_marc('651a', alternate_script: false) do |record, accumulator|
  accumulator.map! { |v| v.gsub(/[\\,;]$/, '') }
  accumulator.map! { |v| v.gsub(/([A-Za-z0-9]{2}|\))[\\,;\.]\.?\s*$/, '\1') }
end
to_field "geographic_facet" do |record, accumulator|
  Traject::MarcExtractor.new((600...699).map { |x| "#{x}z" }.join(':'), alternate_script: false).collect_matching_lines(record) do |field, spec, extractor|
    accumulator << field['z'] if field['z'] # take only the first subfield z
  end

  accumulator.map! { |v| v.gsub(/[\\,;]$/, '') }
  accumulator.map! { |v| v.gsub(/([A-Za-z0-9]{2}|\))[\\,;\.]\.?\s*$/, '\1') }
end

to_field "era_facet", extract_marc("650y:651y", alternate_script: false) do |record, accumulator|
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.map! { |v| trim_punctuation_custom(v, /([A-Za-z0-9]{2})\. *\Z/) }
end

# # Publication Fields

# 260ab and 264ab, without s.l in 260a and without s.n. in 260b
to_field 'pub_search' do |record, accumulator|
  Traject::MarcExtractor.new('260:264', alternate_script: false).collect_matching_lines(record) do |field, spec, extractor|
    data = field.subfields.select { |x| x.code == 'a' || x.code == 'b' }
                 .reject { |x| x.code == 'a' && (x.value =~ /s\.l\./i || x.value =~ /place of .* not identified/i) }
                 .reject { |x| x.code == 'b' && (x.value =~ /s\.n\./i || x.value =~ /r not identified/i) }
                 .map(&:value)

    accumulator << trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff(data.join(' ')) unless data.empty?
  end
end
to_field 'vern_pub_search', extract_marc('260ab:264ab', alternate_script: :only)
to_field 'pub_country', extract_marc('008') do |record, accumulator|
  three_char_country_codes = accumulator.flat_map { |v| v[15..17] }
  two_char_country_codes = accumulator.flat_map { |v| v[15..16] }
  translation_map = Traject::TranslationMap.new('country_map')
  accumulator.replace [translation_map.translate_array(three_char_country_codes + two_char_country_codes).first]
end

# # deprecated
# returns the publication date from a record, if it is present and not
#      *  beyond the current year + 1 (and not earlier than EARLIEST_VALID_YEAR if it is a
#      *  4 digit year
#      *   four digit years < EARLIEST_VALID_YEAR trigger an attempt to get a 4 digit date from 260c
to_field 'pub_date' do |record, accumulator|
  valid_range = 500..(Time.now.year + 10)

  f008_bytes7to10 = record['008'].value[7..10] if record['008']

  year = case f008_bytes7to10
  when /\d\d\d\d/
    year = record['008'].value[7..10].to_i
    record['008'].value[7..10] if valid_range.cover? year
  when /\d\d\d[u-]/
    "#{record['008'].value[7..9]}0s" if record['008'].value[7..9] <= Time.now.year.to_s[0..2]
  when /\d\d[u-][u-]/
    if record['008'].value[7..8] <= Time.now.year.to_s[0..1]
      century_year = (record['008'].value[7..8].to_i + 1).to_s

      century_suffix = if ['11', '12', '13'].include? century_year
        "th"
      else
        case century_year[-1]
        when '1'
          'st'
        when '2'
          'nd'
        when '3'
          'rd'
        else
          'th'
        end
      end

      "#{century_year}#{century_suffix} century"
    end
  end

  # find a valid year in the 264c with ind2 = 1
  year ||= Traject::MarcExtractor.new('264c').to_enum(:collect_matching_lines, record).map do |field, spec, extractor|
    next unless field.indicator2 == '1'
    extractor.collect_subfields(field, spec).map { |value| clean_date_string(value) }.first
  end.compact.first

  year ||= Traject::MarcExtractor.new('260c:264c').to_enum(:collect_matching_lines, record).map do |field, spec, extractor|
    extractor.collect_subfields(field, spec).map { |value| clean_date_string(value) }.first
  end.compact.first

  accumulator << year.to_s if year
end

# *  use 008 date1 if it is 3 or 4 digits and in valid range
# *  If not, check for a 4 digit date in the 264c if 2nd ind is 1
# *  If not, take usable 260c date
# *  If not, take any other usable date in the 264c
# *  If still without date, look at 008 date2
# *
# *  If still without date, use dduu from date 1 as dd00
# *  If still without date, use dduu from date 2 as dd99
to_field 'pub_date_sort' do |record, accumulator|
  valid_range = 500..(Time.now.year + 10)

  f008_bytes7to10 = record['008'].value[7..10] if record['008']

  year = case f008_bytes7to10
  when /\d\d\d\d/
    year = record['008'].value[7..10].to_i
    record['008'].value[7..10] if valid_range.cover? year
  when /\d\d\d[u-]/
    "#{record['008'].value[7..9]}0" if record['008'].value[7..9] <= Time.now.year.to_s[0..2]
  end

  f008_bytes11to14 = record['008'].value[11..14] if record['008']
  year ||= case f008_bytes11to14
  when /\d\d\d\d/
    year = record['008'].value[11..14].to_i
    record['008'].value[11..14] if valid_range.cover? year
  when /\d\d\d[u-]/
    "#{record['008'].value[11..13]}9" if record['008'].value[11..13] <= Time.now.year.to_s[0..2]
  end

  # find a valid year in the 264c with ind2 = 1
  year ||= Traject::MarcExtractor.new('264c', alternate_script: false).to_enum(:collect_matching_lines, record).map do |field, spec, extractor|
    next unless field.indicator2 == '1'
    extractor.collect_subfields(field, spec).map { |value| clean_date_string(value) }.first
  end.compact.first

  year ||= Traject::MarcExtractor.new('260c:264c', alternate_script: false).to_enum(:collect_matching_lines, record).map do |field, spec, extractor|
    extractor.collect_subfields(field, spec).map { |value| clean_date_string(value) }.first
  end.compact.first

  # hyphens sort before 0, so the lexical sorting will be correct. I think.
  year ||= if f008_bytes7to10 =~ /\d\d[u-][u-]/
    "#{record['008'].value[7..8]}--" if record['008'].value[7..8] <= Time.now.year.to_s[0..1]
  end

  # colons sort after 9, so the lexical sorting will be correct. I think.
  # NOTE: the solrmarc code has this comment, and yet still uses hyphens below; maybe a bug?
  year ||= if f008_bytes11to14 =~ /\d\d[u-][u-]/
    "#{record['008'].value[11..12]}--" if record['008'].value[11..12] <= Time.now.year.to_s[0..1]
  end

  accumulator << year.to_s if year
end

to_field 'pub_year_tisim' do |record, accumulator|
  valid_range = 500..(Time.now.year + 10)

  if record['008']
    f008_bytes7to10 = record['008'].value[7..10]

    year_date1 = case f008_bytes7to10
    when /\d\d\d\d/
      year = record['008'].value[7..10].to_i
      record['008'].value[7..10] if valid_range.cover? year
    when /\d\d\d[u-]/
      "#{record['008'].value[7..9]}0" if record['008'].value[7..9] <= Time.now.year.to_s[0..2]
    end

    f008_bytes11to14 = record['008'].value[11..14]
    year_date2 = case f008_bytes11to14
    when /\d\d\d\d/
      year = record['008'].value[11..14].to_i
      record['008'].value[11..14] if valid_range.cover? year
    when /\d\d\d[u-]/
      "#{record['008'].value[11..13]}9" if record['008'].value[11..13] <= Time.now.year.to_s[0..2]
    end

    case record['008'].value[6]
    when 'd', 'i', 'k', 'q', 'm'
      # index start, end and years between
      accumulator << year_date1 if year_date1
      accumulator << year_date2 if year_date2 && year_date2 != '9999'
      accumulator.concat(((year_date1.to_i)..(year_date2.to_i)).map(&:to_s)) if year_date1 && year_date2 && year_date2 != '9999'
    when 'c'
      # if open range, index all thru present
      if year_date1
        accumulator << year_date1
        accumulator.concat(((year_date1.to_i)..(Time.now.year)).map(&:to_s)) if f008_bytes11to14 == '9999'
      end
    when 'p', 'r', 't'
      # index only start and end
      accumulator << year_date1 if year_date1
      accumulator << year_date2 if year_date2
    else
      accumulator << year_date1 if year_date1
    end
  end

  if accumulator.empty?
    Traject::MarcExtractor.new('260c', alternate_script: false).collect_matching_lines(record) do |field, spec, extractor|
      accumulator.concat extractor.collect_subfields(field, spec).map { |value| clean_date_string(value) }
    end
  end

  accumulator.compact!
  accumulator.map!(&:to_i)
  accumulator.map!(&:to_s)
end

# Year/range to show with the title
to_field 'pub_year_ss' do |record, accumulator|
  next unless record['008']

  date_type = record['008'].value[6]
  next unless %w[c d e i k m p q r s t u].include? date_type

  date1 = clean_marc_008_date(record['008'].value[7..10], u_replacement: '0')
  date2 = clean_marc_008_date(record['008'].value[11..14], u_replacement: '9')

  next if (date1.nil? || date1.empty?) && (date2.nil? || date2.empty?)

  accumulator << case date_type
                 when 'e', 's'
                   date1
                 when 'p', 'r', 't'
                   date2 || date1
                 when 'c', 'd', 'm', 'u', 'i', 'k'
                   "#{date1} - #{date2}"
                 when 'q'
                   "#{date1} ... #{date2}"
                 end
end

# # from 008 date 1
to_field 'publication_year_isi', marc_008_date(%w[e s t], 7..10, '0')
to_field 'beginning_year_isi', marc_008_date(%w[c d m u], 7..10, '0')
to_field 'earliest_year_isi', marc_008_date(%w[i k], 7..10, '0')
to_field 'earliest_poss_year_isi', marc_008_date(%w[q], 7..10, '0')
to_field 'release_year_isi', marc_008_date(%w[p], 7..10, '0')
to_field 'reprint_year_isi', marc_008_date(%w[r], 7..10, '0')
to_field 'other_year_isi' do |record, accumulator|
  Traject::MarcExtractor.new('008').collect_matching_lines(record) do |field, spec, extractor|
    unless %w[c d e i k m p q r s t u].include? field.value[6]
      year = field.value[7..10]
      next unless year =~ /(\d{4}|\d{3}[u-])/
      year.gsub!(/[u-]$/, '0')
      next unless (500..(Time.now.year + 10)).include? year.to_i
      accumulator << year.to_i.to_s
    end
  end
end

# # from 008 date 2
to_field 'ending_year_isi', marc_008_date(%w[d m], 11..14, '9')
to_field 'latest_year_isi', marc_008_date(%w[i k], 11..14, '9')
to_field 'latest_poss_year_isi', marc_008_date(%w[q], 11..14, '9')
to_field 'production_year_isi', marc_008_date(%w[p], 11..14, '9')
to_field 'original_year_isi', marc_008_date(%w[r], 11..14, '9')
to_field 'copyright_year_isi', marc_008_date(%w[t], 11..14, '9')

# returns the a value comprised of 250ab, 260a-g, and some 264 fields, suitable for display
to_field 'imprint_display' do |record, accumulator|
  edition = Traject::MarcExtractor.new('250ab', alternate_script: false).extract(record).uniq.map(&:strip).join(' ')
  vernEdition = Traject::MarcExtractor.new('250ab', alternate_script: :only).extract(record).uniq.map(&:strip).join(' ')

  imprint = Traject::MarcExtractor.new('2603abcefg', alternate_script: false).extract(record).uniq.map(&:strip).join(' ')
  vernImprint = Traject::MarcExtractor.new('2603abcefg', alternate_script: :only).extract(record).uniq.map(&:strip).join(' ')

  all_pub = Traject::MarcExtractor.new('2643abc', alternate_script: false).extract(record).uniq.map(&:strip)
  all_vernPub = Traject::MarcExtractor.new('2643abc', alternate_script: :only).extract(record).uniq.map(&:strip)

  bad_pub = Traject::MarcExtractor.new('264| 4|3abc:264|24|3abc:264|34|3abc', alternate_script: false).extract(record).uniq.map(&:strip)
  bad_vernPub = Traject::MarcExtractor.new('264| 4|3abc:264|24|3abc:264|34|3abc', alternate_script: :only).extract(record).uniq.map(&:strip)

  pub = (all_pub - bad_pub).join(' ')
  vernPub = (all_vernPub - bad_vernPub).join(' ')
  data = [
    [edition, vernEdition].compact.reject(&:empty?).join(' '),
    [imprint, vernImprint].compact.reject(&:empty?).join(' '),
    [pub, vernPub].compact.reject(&:empty?).join(' ')
  ].compact.reject(&:empty?)

  accumulator << data.join(' - ') if data.any?
end

#
# # Date field for new items feed
# FIXME: FOLIO records don't have 916s?
to_field "date_cataloged", extract_marc("916b") do |record, accumulator|
  accumulator.reject! { |v| v =~ /NEVER/i }

  accumulator.map! do |v|
    "#{v[0..3]}-#{v[4..5]}-#{v[6..7]}T00:00:00Z"
  end
end

to_field 'language', extract_marc('008') do |record, accumulator|
  translation_map = Traject::TranslationMap.new('marc_languages')
  accumulator.replace translation_map.translate_array(accumulator.map { |v| v[35..37] }).flatten
end

to_field 'language', extract_marc('041d:041e:041j') do |record, accumulator|
  accumulator.map!(&:strip)
  translation_map = Traject::TranslationMap.new('marc_languages')
  accumulator.replace translation_map.translate_array(accumulator)
end

to_field 'language', extract_marc('041a') do |record, accumulator|
  accumulator.map!(&:strip)
  translation_map = Traject::TranslationMap.new("marc_languages")
  accumulator.select! { |value|  (value.length % 3) == 0 }
  codes = accumulator.flat_map { |value| value.length == 3 ? value : value.chars.each_slice(3).map(&:join) }

  codes = codes.uniq
  translation_map.translate_array!(codes)
  accumulator.replace codes
end

# TODO: implement url fulltext (856/956)

# Not using traject's oclcnum here because we have more complicated logic
to_field 'oclc' do |record, accumulator|
  marc035_with_m_suffix = []
  marc035_without_m_suffix = []
  Traject::MarcExtractor.new('035a', separator: nil).extract(record).map do |data|
    if data.start_with?('(OCoLC-M)')
      marc035_with_m_suffix << data.sub(/^\(OCoLC-M\)\s*/, '')
    elsif data.start_with?('(OCoLC)')
      marc035_without_m_suffix << data.sub(/^\(OCoLC\)\s*/, '')
    end
  end.flatten.compact.uniq

  marc079 = Traject::MarcExtractor.new('079a', separator: nil).extract(record).map do |data|
    regex = /\A(?:ocm)|(?:ocn)|(?:on)/
    next unless data[regex]
    data.sub(regex, '')
  end.flatten.compact.uniq

  if marc035_with_m_suffix.any?
    accumulator.concat marc035_with_m_suffix
  elsif marc079.any?
    accumulator.concat marc079
  elsif marc035_without_m_suffix.any?
    accumulator.concat marc035_without_m_suffix
  end
end

to_field 'access_facet' do |record, accumulator, context|
  online_locs = ['E-RECVD', 'E-RESV', 'ELECTR-LOC', 'INTERNET', 'KIOST', 'ONLINE-TXT', 'RESV-URL', 'WORKSTATN']
  on_order_ignore_locs = %w[ENDPROCESS INPROCESS LAC SPEC-INPRO]
  
  holdings(record, context).each do |holding|
    next if holding.skipped?

    if online_locs.include?(holding.current_location) || online_locs.include?(holding.home_location) || holding.e_call_number?
      accumulator << 'Online'
    elsif holding.call_number.to_s =~ /^XX/ && (holding.current_location == 'ON-ORDER' || (!holding.current_location.nil? && !holding.current_location.empty? && (on_order_ignore_locs & [holding.current_location, holding.home_location]).empty? && holding.library != 'HV-ARCHIVE'))
      accumulator << 'On order'
    else
      accumulator << 'At the Library'
    end
  end

  accumulator << 'On order' if accumulator.empty?
  accumulator << 'Online' if context.output_hash['url_fulltext']
  accumulator << 'Online' if context.output_hash['url_sfx']

  accumulator.uniq!
end

##
# Lane Medical Library relies on the underlying logic of "format_main_ssim"
# data (next ~200+ lines) to accurately represent SUL records in
# http://lane.stanford.edu. Please consider notifying Ryan Steinberg
# (ryanmax at stanford dot edu) or LaneAskUs@stanford.edu in the event of
# changes to this logic.
#
# # old format field, left for continuity in UI URLs for old formats
# format = custom, getOldFormats
to_field 'format_main_ssim' do |record, accumulator|
  value = case record.leader[6]
  when 'a', 't'
    arr = []

    if ['a', 'm'].include? record.leader[7]
      arr << 'Book'
    end

    if record.leader[7] == 'c'
      arr << 'Archive/Manuscript'
    end

    arr
  when 'b', 'p'
    'Archive/Manuscript'
  when 'c'
    'Music score'
  when 'd'
    ['Music score', 'Archive/Manuscript']
  when 'e'
    'Map'
  when 'f'
    ['Map', 'Archive/Manuscript']
  when 'g'
    if record['008'] && record['008'].value[33] =~ /[ |[0-9]fmv]/
      'Video'
    elsif record['008'] && record['008'].value[33] =~ /[aciklnopst]/
      'Image'
    end
  when 'i'
    'Sound recording'
  when 'j'
    'Music recording'
  when 'k'
    'Image' if record['008'] && record['008'].value[33] =~ /[ |[0-9]aciklnopst]/
  when 'm'
    if record['008'] && record['008'].value[26] == 'a'
      'Dataset'
    else
      'Software/Multimedia'
    end
  when 'o' # instructional kit
    'Other'
  when 'r' # 3D object
    'Object'
  end

  accumulator.concat(Array(value))
end

to_field 'format_main_ssim' do |record, accumulator, context|
  next unless context.output_hash['format_main_ssim'].nil?

  accumulator << if record.leader[7] == 's' && record['008'] && record['008'].value[21]
    case record['008'].value[21]
    when 'm'
      'Book'
    when 'n'
      'Newspaper'
    when 'p', ' ', '|', '#'
      'Journal/Periodical'
    when 'd'
      'Database'
    when 'w'
      'Journal/Periodical'
    else
      'Book'
    end
  elsif record['006'] && record['006'].value[0] == 's'
    case record['006'].value[4]
    when 'l', 'm'
      'Book'
    when 'n'
      'Newspaper'
    when 'p', ' ', '|', '#'
      'Journal/Periodical'
    when 'd'
      'Database'
    when 'w'
      'Journal/Periodical'
    else
      'Book'
    end
  end
end

to_field 'format_main_ssim' do |record, accumulator, context|
  next unless context.output_hash['format_main_ssim'].nil?

  if record.leader[7] == 'i'
    accumulator << case record['008'].value[21]
    when nil
      nil
    when 'd'
      'Database'
    when 'l'
      'Book'
    when 'w'
      'Journal/Periodical'
    else
      'Book'
    end
  end
end

# SW-4108
to_field 'format_main_ssim' do |record, accumulator, context|
  Traject::MarcExtractor.new('655a').collect_matching_lines(record) do |field, spec, extractor|
    accumulator << 'Dataset' if extractor.collect_subfields(field, spec).include? 'Data sets'
  end

  Traject::MarcExtractor.new('336a').collect_matching_lines(record) do |field, spec, extractor|
    if ['computer dataset', 'cartographic dataset'].any? { |v| extractor.collect_subfields(field, spec).include?(v) }
      accumulator << 'Dataset'
    end
  end
end

# TODO: 999 is different for FOLIO records
to_field 'format_main_ssim' do |record, accumulator, context|
  Traject::MarcExtractor.new('999t').collect_matching_lines(record) do |field, spec, extractor|
    accumulator << 'Database' if extractor.collect_subfields(field, spec).include? 'DATABASE'
  end
end

to_field 'format_main_ssim' do |record, accumulator, context|
  # if it is a Database and a Software/Multimedia, and it is not
  #  "At the Library", then it should only be a Database
  if context.output_hash.fetch('format_main_ssim', []).include?('Database') && context.output_hash['format_main_ssim'].include?('Software/Multimedia') && !Array(context.output_hash['access_facet']).include?('At the Library')
    context.output_hash['format_main_ssim'].delete('Software/Multimedia')
  end
end

# TODO: 999 is different for FOLIO records
# /* If the call number prefixes in the MARC 999a are for Archive/Manuscript items, add Archive/Manuscript format
#  * A (e.g. A0015), F (e.g. F0110), M (e.g. M1810), MISC (e.g. MISC 1773), MSS CODEX (e.g. MSS CODEX 0335),
#   MSS MEDIA (e.g. MSS MEDIA 0025), MSS PHOTO (e.g. MSS PHOTO 0463), MSS PRINTS (e.g. MSS PRINTS 0417),
#   PC (e.g. PC0012), SC (e.g. SC1076), SCD (e.g. SCD0012), SCM (e.g. SCM0348), and V (e.g. V0321).  However,
#   A, F, M, PC, and V are also in the Library of Congress classification which could be in the 999a, so need to make sure that
#   the call number type in the 999w == ALPHANUM and the library in the 999m == SPEC-COLL.
#  */
to_field 'format_main_ssim' do |record, accumulator|
  Traject::MarcExtractor.new('999').collect_matching_lines(record) do |field, spec, extractor|
    if field['m'] == 'SPEC-COLL' && field['w'] == 'ALPHANUM' && field['a'] =~ /^(A\d|F\d|M\d|MISC \d|(MSS (CODEX|MEDIA|PHOTO|PRINTS))|PC\d|SC[\d|D|M]|V\d)/i
      accumulator << 'Archive/Manuscript'
    end
  end
end

# TODO: 999 is different for FOLIO records
to_field 'format_main_ssim' do |record, accumulator, context|
  Traject::MarcExtractor.new('245h').collect_matching_lines(record) do |field, spec, extractor|
    if extractor.collect_subfields(field, spec).join(' ') =~ /manuscript/

      Traject::MarcExtractor.new('999m').collect_matching_lines(record) do |m_field, m_spec, m_extractor|
        if m_extractor.collect_subfields(m_field, m_spec).any? { |x| x == 'LANE-MED' }
          accumulator << 'Book'
        end
      end
    end
  end
end

# TODO: 999 is different for FOLIO records
to_field 'format_main_ssim' do |record, accumulator, context|
  if (record.leader[6] == 'a' || record.leader[6] == 't') && (record.leader[7] == 'c' || record.leader[7] == 'd')
    Traject::MarcExtractor.new('999m').collect_matching_lines(record) do |m_field, m_spec, m_extractor|
      if m_extractor.collect_subfields(m_field, m_spec).any? { |x| x == 'LANE-MED' }
        context.output_hash.fetch('format_main_ssim', []).delete('Archive/Manuscript')
        accumulator << 'Book'
      end
    end
  end
end

to_field 'format_main_ssim' do |record, accumulator|
  Traject::MarcExtractor.new('590a', alternate_script: false).collect_matching_lines(record) do |field, spec, extractor|
    if extractor.collect_subfields(field, spec).any? { |x| x =~ /MARCit brief record/ }
      accumulator << 'Journal/Periodical'
    end
  end
end

# TODO: 914 on FOLIO records?
to_field 'format_main_ssim' do |record, accumulator, context|
  # // If it is Equipment, add Equipment resource type and remove 3D object resource type
  # // INDEX-123 If it is Equipment, that should be the only item in main_formats
  Traject::MarcExtractor.new('914a').collect_matching_lines(record) do |field, spec, extractor|
    if extractor.collect_subfields(field, spec).include? 'EQUIP'
      context.output_hash['format_main_ssim'].replace([])
      accumulator << 'Equipment'
    end
  end
end

to_field 'format_main_ssim' do |record, accumulator, context|
  if context.output_hash['format_main_ssim'].nil? || context.output_hash['format_main_ssim'].include?('Other')
    format = Traject::MarcExtractor.new('245h', alternate_script: false).collect_matching_lines(record) do |field, spec, extractor|
      value = extractor.collect_subfields(field, spec).join(' ').downcase

      case value
      when /(video|motion picture|filmstrip|vcd-dvd)/
        'Video'
      when /manuscript/
        'Archive/Manuscript'
      when /sound recording/
        'Sound recording'
      when /(graphic|slide|chart|art reproduction|technical drawing|flash card|transparency|activity card|picture|diapositives)/
        'Image'
      when /kit/
        if record['007']
          case record['007'].value[0]
          when 'a', 'd'
            'Map'
          when 'c'
            'Software/Multimedia'
          when 'g', 'm', 'v'
            'Video'
          when 'k', 'r'
            'Image'
          when 'q'
            'Music score'
          when 's'
            'Sound recording'
          end
        end
      end
    end

    if format
      accumulator.concat format
      context.output_hash['format_main_ssim'].delete('Other') if context.output_hash['format_main_ssim']
    end
  end
end

to_field 'format_main_ssim' do |record, accumulator, context|
  next if context.output_hash['format_main_ssim'].nil?

  context.output_hash['format_main_ssim'].delete('Other') if context.output_hash['format_main_ssim']
end

# TODO: 999 is different for FOLIO records
# * INDEX-89 - Add video physical formats
to_field 'format_physical_ssim', extract_marc('999a') do |record, accumulator|
  accumulator.replace(accumulator.flat_map do |value|
    result = []

    result << 'Blu-ray' if value =~ /BLU-RAY/
    result << 'Videocassette (VHS)' if value =~ Regexp.union(/ZVC/, /ARTVC/, /MVC/)
    result << 'DVD' if value =~ Regexp.union(/ZDVD/, /ARTDVD/, /MDVD/, /ADVD/)
    result << 'Videocassette' if value =~ /AVC/
    result << 'Laser disc' if value =~ Regexp.union(/ZVD/, /MVD/)

    result unless result.empty?
  end)

  accumulator.compact!
end

to_field 'format_physical_ssim', extract_marc('007') do |record, accumulator, context|
  accumulator.replace(accumulator.map do |value|
    case value[0]
    when 'g'
      'Slide' if value[1] == 's'
    when 'h'
      if value[1] =~ /[bcdhj]/
        'Microfilm'
      elsif value[1] =~ /[efg]/
        'Microfiche'
      end
    when 'k'
      'Photo' if value[1] == 'h'
    when 'm'
      'Film'
    when 'r'
      'Remote-sensing image'
    when 's'
      if Array(context.output_hash['access_facet']).include? 'At the Library'
        case value[1]
        when 'd'
          case value[3]
          when 'b'
            'Vinyl disc'
          when 'd'
            '78 rpm (shellac)'
          when 'f'
            'CD'
          end
        else
          if value[6] == 'j'
            'Audiocassette'
          elsif value[1] == 'q'
            'Piano/Organ roll'
          end
        end
      end
    when 'v'
      case value[4]
      when 'a', 'i', 'j'
        'Videocassette (Beta)'
      when 'b'
        'Videocassette (VHS)'
      when 'g'
        'Laser disc'
      when 'q'
        'Hi-8 mm'
      when 's'
        'Blu-ray'
      when 'v'
        'DVD'
      when nil, ''
      else
        'Other video'
      end
    end

  end)
end

# INDEX-89 - Add video physical formats from 538$a
to_field 'format_physical_ssim', extract_marc('538a', alternate_script: false) do |record, accumulator|
  video_formats = accumulator.dup
  accumulator.replace([])

  video_formats.each do |value|
    accumulator << 'Blu-ray' if value =~ Regexp.union(/Bluray/, /Blu-ray/, /Blu ray/)
    accumulator << 'Videocassette (VHS)' if value =~ Regexp.union(/VHS/)
    accumulator << 'DVD' if value =~ Regexp.union(/DVD/)
    accumulator << 'Laser disc' if value =~ Regexp.union(/CAV/, /CLV/)
    accumulator << 'Video CD' if value =~ Regexp.union(/VCD/, /Video CD/, /VideoCD/)
  end
end

# INDEX-89 - Add video physical formats from 300$b, 347$b
to_field 'format_physical_ssim', extract_marc('300b', alternate_script: false) do |record, accumulator|
  accumulator.replace(accumulator.map do |value|
    case value
    when /MP4/
      'MPEG-4'
    when /VCD/, /Video CD/, /VideoCD/
      'Video CD'
    end
  end)
end

to_field 'format_physical_ssim', extract_marc('347b', alternate_script: false) do |record, accumulator|
  accumulator.replace(accumulator.map do |value|
    case value
    when /MPEG-4/
      'MPEG-4'
    when /VCD/, /Video CD/, /VideoCD/
      'Video CD'
    end
  end)
end

to_field 'format_physical_ssim', extract_marc('300a:338a', alternate_script: false) do |record, accumulator|
  accumulator.replace(accumulator.map do |value|
    case value
    when /audio roll/, /piano roll/, /organ roll/
      'Piano/Organ roll'
    end
  end)
end

# TODO: 999 is different for FOLIO records
to_field 'format_physical_ssim' do |record, accumulator|
  Traject::MarcExtractor.new('999').collect_matching_lines(record) do |field, spec, extractor|
    next unless field['a']

    if field['a'].start_with? 'MFICHE'
      accumulator << 'Microfiche'
    elsif field['a'].start_with? 'MFILM'
      accumulator << 'Microfilm'
    end
  end
end

to_field 'format_physical_ssim', extract_marc("300#{ALPHABET}", alternate_script: false) do |record, accumulator|
  values = accumulator.dup
  accumulator.replace([])

  values.each do |value|
    if value =~ %r{(sound|audio) discs? (\((ca. )?\d+.*\))?\D+((digital|CD audio)\D*[,\;.])? (c )?(4 3/4|12 c)}
      accumulator << 'CD' unless value =~ /(DVD|SACD|blu[- ]?ray)/
    end

    if value =~ %r{33(\.3| 1/3) ?rpm}
      accumulator << 'Vinyl disc' if value =~ /(10|12) ?in/
    end
  end
end

to_field 'characteristics_ssim' do |marc, accumulator|
  {
    '344' => 'Sound',
    '345' => 'Projection',
    '346' => 'Video',
    '347' => 'Digital'
  }.each do |tag, label|
    if marc[tag]
      characteristics_fields = ''
      marc.find_all {|f| tag == f.tag }.each do |field|
        subfields = field.map do |subfield|
          if ('a'..'z').include?(subfield.code) && !Constants::EXCLUDE_FIELDS.include?(subfield.code)
            subfield.value
          end
        end.compact.join('; ')
        characteristics_fields << "#{subfields}." unless subfields.empty?
      end

      accumulator << "#{label}: #{characteristics_fields}" unless characteristics_fields.empty?
    end
  end
end

to_field 'format_physical_ssim', extract_marc('300a', alternate_script: false) do |record, accumulator|
  values = accumulator.dup.join("\n")
  accumulator.replace([])

  accumulator << 'Microfiche' if values =~ /microfiche/i
  accumulator << 'Microfilm' if values =~ /microfilm/i
  accumulator << 'Photo' if values =~ /photograph/i
  accumulator << 'Remote-sensing image' if values =~ Regexp.union(/remote-sensing image/i, /remote sensing image/i)
  accumulator << 'Slide' if values =~ /slide/i
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
