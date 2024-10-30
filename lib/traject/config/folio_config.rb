# frozen_string_literal: true

require_relative '../../../config/boot'
require 'traject/macros/marc21_semantics'
require 'csv'
require 'i18n'
require 'digest/md5'
require 'active_support/core_ext/time'

I18n.available_locales = [:en]

extend Traject::Macros::Marc21
extend Traject::Macros::Marc21Semantics
extend Traject::SolrBetterJsonWriter::IndexerPatch
extend Traject::MarcUtils

Utils.logger = logger

ALPHABET = [*'a'..'z'].join('')
A_X = ALPHABET.slice(0, 24)
CJK_RANGE = /(\p{Han}|\p{Hangul}|\p{Hiragana}|\p{Katakana})/

indexer = self

configure do
  @source_record_id_proc = lambda do |source_record|
    "#{source_record.instance_id} (#{source_record.hrid})" if source_record.is_a? FolioRecord
  end
end

settings do
  provide 'writer_class_name', 'Traject::SolrBetterJsonWriter'
  provide 'solr.url', ENV.fetch('SOLR_URL', nil)

  # Upstream siris_config will provide a default value; we need to override it if it wasn't provided
  if self['kafka.topic']
    provide 'reader_class_name', 'Traject::KafkaFolioReader'

    provide 'kafka.hosts', ::Settings.kafka.hosts
    provide 'kafka.client', Kafka.new(self['kafka.hosts'], logger: Utils.logger)
    consumer = self['kafka.client'].consumer(group_id: self['kafka.consumer_group_id'] || 'traject', fetcher_max_queue_size: 25)
    consumer.subscribe(self['kafka.topic'])
    provide 'kafka.consumer', consumer
  elsif self['postgres.url']
    if self['catkey']
      provide 'postgres.sql_filters', "lower(sul_mod_inventory_storage.f_unaccent(vi.jsonb ->> 'hrid'::text)) = '#{self['catkey'].downcase}'"
    end
    provide 'reader_class_name', 'Traject::FolioPostgresReader'
  elsif self['reader_class_name'] != 'Traject::FolioJsonReader'
    provide 'reader_class_name', 'Traject::FolioReader'
    provide 'folio.client', FolioClient.new(url: self['okapi.url'] || ENV.fetch('OKAPI_URL', ''))
  end

  provide 'allow_duplicate_values',  false
  provide 'skip_empty_item_display', ENV.fetch('SKIP_EMPTY_ITEM_DISPLAY', nil)
  self['skip_empty_item_display'] = self['skip_empty_item_display'].to_i

  provide 'solr_writer.commit_on_close', true
  provide 'mapping_rescue', (lambda do |context, e|
    Honeybadger.notify(e, context: {
                         context: context.record_inspect,
                         record: begin
                           context.source_record.to_honeybadger_context
                         rescue StandardError
                           nil
                         end,
                         index_step: context.index_step.inspect
                       })
    indexer.send(:default_mapping_rescue).call(context, e)
  end)

  provide 'solr_json_writer.http_client', HTTP.timeout(read: 600)
  provide 'solr_json_writer.skippable_exceptions', [HTTP::TimeoutError, StandardError]
end

# Monkey-patch MarcExtractor in order to add logic to strip subfields before
# joining them, for parity with solrmarc.
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

each_record do |_record, context|
  context.clipboard[:benchmark_start_time] = Time.now
end

each_record do |record|
  puts record if ENV['q']
end

##
# Skip records that have a delete field
each_record do |record, context|
  if record.record.dig('instance', 'suppressFromDiscovery')
    context.output_hash['id'] = [record.hrid.sub(/^a/, '')]
    context.skip!('Delete')
  end
end

each_record do |record, context|
  context.skip!('Incomplete record') if record['245'] && record['245']['a'] == '**REQUIRED FIELD**'
end

def items(record, context)
  context.clipboard[:item] ||= record.index_items
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

to_field 'marc_json_struct' do |record, accumulator|
  accumulator << record.to_hash
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
           '505t:700fgklmnoprst:710dfgklmnoprst:711fgklnpst:730adfgklmnoprst:740anp:760st:762st:765st:767st:770st:772st:773st:774st:775st:776st:777st:780st:785st:786st:787st:796fgklmnoprst:797dfgklmnoprst:798fgklnpst:799adfgklmnoprst',
           alternate_script: false
         )
to_field 'vern_title_related_search',
         extract_marc(
           '505tt:700fgklmnoprst:710dfgklmnoprst:711fgklnpst:730adfgklmnoprst:740anp:760st:762st:765st:767st:770st:772st:773st:774st:775st:776st:777st:780st:785st:786st:787st:796fgklmnoprst:797dfgklmnoprst:798fgklnpst:799adfgklmnoprst',
           alternate_script: :only
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

    if !end_link && sub_field.value.strip =~ /[.|;]$/ && sub_field.code != 'h'
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
      next if (Constants::EXCLUDE_FIELDS + %w[4 e]).include?(sub_field.code)

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
          vern:
        },
        authorities: uniform_title.subfields.select { |x| x.code == '0' }.map(&:value),
        rwo: uniform_title.subfields.select { |x| x.code == '1' }.map(&:value)
      }
    ]
  }
end

to_field 'uniform_title_authorities_ssim', extract_marc('1300:1301:2400:2401')

# Series Search Fields
to_field 'series_search', extract_marc('440anpv:490av', alternate_script: false)

to_field 'series_search',
         extract_marc("800#{A_X}:810#{A_X}:811#{A_X}:830#{A_X}", alternate_script: false) do |_record, accumulator|
  accumulator.map!(&method(:trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff))
end

to_field 'vern_series_search',
         extract_marc("440anpv:490av:800#{A_X}:810#{A_X}:811#{A_X}:830#{A_X}", alternate_script: :only)
to_field 'series_exact_search', extract_marc('830a', alternate_script: false)

to_field 'author_title_245ac_search', extract_marc('245ac', alternate_script: false)
to_field 'vern_author_title_245ac_search', extract_marc('245ac', alternate_script: :only)

to_field 'author_title_1xx_search' do |record, accumulator|
  onexx = trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff(Traject::MarcExtractor.cached('100abcq:110abn:111aeq', alternate_script: false).extract(record).first)
  twoxx = trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff(Traject::MarcExtractor.cached('240' + ALPHABET, alternate_script: false).extract(record).first)
  twoxx ||= Traject::MarcExtractor.cached('245aa', alternate_script: false).extract(record).first

  accumulator << [onexx, twoxx].compact.reject(&:empty?).map(&:strip).join(' ') if onexx
end

to_field 'vern_author_title_1xx_search' do |record, accumulator|
  onexx = trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff(Traject::MarcExtractor.cached('100abcq:110abn:111aeq', alternate_script: :only).extract(record).first)
  twoxx = trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff(Traject::MarcExtractor.cached('240' + ALPHABET, alternate_script: :only).extract(record).first)
  twoxx ||= Traject::MarcExtractor.cached('245aa', alternate_script: :only).extract(record).first

  accumulator << [onexx, twoxx].compact.reject(&:empty?).map(&:strip).join(' ') if onexx
end

# # Author Title Search Fields
to_field 'author_title_search' do |record, accumulator|
  onexx = trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff(Traject::MarcExtractor.cached(
    '100abcdfghijklmnopqrstuvwxyz:110abcdfghijklmnopqrstuvwxyz:111abcdefghjklmnopqrstuvwxyz', alternate_script: false
  ).extract(record).first)

  twoxx = trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff(Traject::MarcExtractor.cached(
    '240' + ALPHABET, alternate_script: false
  ).extract(record).first) if record['240']
  twoxx ||= Traject::MarcExtractor.cached('245aa', alternate_script: false).extract(record).first if record['245']
  twoxx ||= 'null'

  accumulator << [onexx, twoxx].compact.reject(&:empty?).map(&:strip).join(' ') if onexx && twoxx
end

to_field 'author_title_search' do |record, accumulator|
  onexx = Traject::MarcExtractor.cached(
    '100abcdfghijklmnopqrstuvwxyz:110abcdfghijklmnopqrstuvwxyz:111abcdefghjklmnopqrstuvwxyz', alternate_script: :only
  ).extract(record).first

  twoxx = Traject::MarcExtractor.cached('240' + ALPHABET, alternate_script: :only).extract(record).first
  accumulator << [onexx, twoxx].compact.reject(&:empty?).map(&:strip).join(' ') if onexx && twoxx
end

to_field 'best_author_title_search' do |_record, accumulator, context|
  accumulator << context.output_hash['author_title_search'].first if context.output_hash['author_title_search']
end

to_field 'author_title_search' do |record, accumulator|
  Traject::MarcExtractor.cached('700abcdfghjklmnopqrstuvwyz:710abcdfghjklmnopqrstuvwyz:711abcdefghjklmnopqrstuvwyz',
                                alternate_script: false).collect_matching_lines(record) do |field, spec, extractor|
    accumulator.concat extractor.collect_subfields(field, spec) if field['t']
  end
end

to_field 'author_title_search' do |record, accumulator|
  Traject::MarcExtractor.cached('700abcdfghjklmnopqrstuvwyz:710abcdfghjklmnopqrstuvwyz:711abcdefghjklmnopqrstuvwyz',
                                alternate_script: :only).collect_matching_lines(record) do |field, spec, extractor|
    accumulator.concat extractor.collect_subfields(field, spec) if field['t']
  end
end

to_field 'author_title_search' do |record, accumulator|
  Traject::MarcExtractor.cached('800abcdfghijklmnopqrstuyz:810abcdfghijklmnopqrstuyz:811abcdfghijklmnopqrstuyz').collect_matching_lines(record) do |field, spec, extractor|
    accumulator.concat extractor.collect_subfields(field, spec) if field['t']
  end
end

to_field 'author_title_search' do |record, accumulator|
  onexx = trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff(Traject::MarcExtractor.cached('100abcdfghijklmnopqrstuvwxyz:110abcdfghijklmnopqrstuvwxyz:111abcdefghjklmnopqrstuvwxyz',
                                                                                                                  alternate_script: false).extract(record).first)

  twoxx = Traject::MarcExtractor.cached('245aa', alternate_script: false).extract(record).first if record['245']
  accumulator << [onexx, twoxx].compact.reject(&:empty?).map(&:strip).join(' ') if onexx && twoxx
end

to_field 'author_title_search' do |record, accumulator|
  onexx = Traject::MarcExtractor.cached('100abcdfghijklmnopqrstuvwxyz:110abcdfghijklmnopqrstuvwxyz:111abcdefghjklmnopqrstuvwxyz', alternate_script: :only).extract(record).first

  twoxx = Traject::MarcExtractor.cached('245aa', alternate_script: :only).extract(record).first
  accumulator << [onexx, twoxx].compact.reject(&:empty?).map(&:strip).join(' ') if onexx && twoxx
end

# # Author Search Fields
# # IFF relevancy of author search needs improvement, unstemmed flavors for author search
# #   (keep using stemmed version for everything search to match stemmed query)
to_field 'author_1xx_search', extract_marc('100abcdgjqu:110abcdgnu:111acdegjnqu', first: true, alternate_script: false)
to_field 'vern_author_1xx_search',
         extract_marc('100abcdgjqu:110abcdgnu:111acdegjnqu', first: true, alternate_script: :only)
to_field 'author_7xx_search',
         extract_marc('700abcdgjqu:720ae:796abcdgjqu:710abcdgnu:797abcdgnu:711acdejngqu:798acdegjnqu',
                      alternate_script: false)
to_field 'vern_author_7xx_search',
         extract_marc('700abcdgjqu:720ae:796abcdgjqu:710abcdgnu:797abcdgnu:711acdegjnqu:798acdegjnqu',
                      alternate_script: :only)
to_field 'author_8xx_search', extract_marc('800abcdegjqu:810abcdegnu:811acdegjnqu', alternate_script: false)
to_field 'vern_author_8xx_search', extract_marc('800abcdegjqu:810abcdegnu:811acdegjnqu', alternate_script: :only)
# # Author Facet Fields
to_field 'author_person_facet', extract_marc('100abcdq:700abcdq', alternate_script: false) do |_record, accumulator|
  accumulator.map! { |v| v.gsub(/([)-])[\\,;:]\.?$/, '\1') }
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'author_other_facet',
         extract_marc('110abcdn:111acdn:710abcdn:711acdn', alternate_script: false) do |_record, accumulator|
  accumulator.map! { |v| v.gsub(/(\))\.?$/, '\1') }
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.map!(&method(:trim_punctuation_custom))
end
# # Author Display Fields
to_field 'author_person_display',
         extract_marc('100abcdq', first: true, alternate_script: false) do |_record, accumulator|
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'vern_author_person_display',
         extract_marc('100abcdq', first: true, alternate_script: :only) do |_record, accumulator|
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
    included: works_struct(record, '700:710:711:730:740', indicator2: '2')&.compact,
    related: works_struct(record, '700:710:711:730:740', indicator2: nil)&.compact
  }

  accumulator << struct unless struct.values.all?(&:empty?)
end

to_field 'author_authorities_ssim',
         extract_marc('1001:1000:1100:1101:1110:1111:7000:7001:7100:7101:7110:7111:7200:7201:7300:7301:7400:7401')

#
# # Subject Search Fields
# #  should these be split into more separate fields?  Could change relevancy if match is in field with fewer terms
to_field 'topic_search',
         extract_marc(
           '650abcdefghijklmnopqrstuw:653abcdefghijklmnopqrstuw:654abcdefghijklmnopqrstuw:690abcdefghijklmnopqrstuw:795ap', alternate_script: false
         ) do |record, accumulator, context|
  accumulator.reject! { |v| v.start_with?('nomesh') }
  if items(record, context).any? { |item| item.library == 'LANE' }
    arr = []
    extract_marc('655a').call(record, arr, nil)
    accumulator.reject! { |v| arr.include? v }
  end
end

to_field 'vern_topic_search',
         extract_marc(
           '650abcdefghijklmnopqrstuw:653abcdefghijklmnopqrstuw:654abcdefghijklmnopqrstuw:690abcdefghijklmnopqrstuw:795ap', alternate_script: :only
         )
to_field 'topic_subx_search',
         extract_marc('600x:610x:611x:630x:647x:650x:651x:655x:656x:657x:690x:691x:696x:697x:698x:699x',
                      alternate_script: false)
to_field 'vern_topic_subx_search',
         extract_marc('600xx:610xx:611xx:630xx:647xx:650xx:651xx:655xx:656xx:657xx:690xx:691xx:696xx:697xx:698xx:699xx',
                      alternate_script: :only)
to_field 'geographic_search',
         extract_marc('651abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw',
                      alternate_script: false)
to_field 'vern_geographic_search',
         extract_marc('651abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw',
                      alternate_script: :only)
to_field 'geographic_subz_search',
         extract_marc('600z:610z:630z:647z:650z:651z:654z:655z:656z:657z:690z:691z:696z:697z:698z:699z',
                      alternate_script: false)

to_field 'vern_geographic_subz_search',
         extract_marc('600zz:610zz:630zz:647zz:650zz:651zz:654zz:655zz:656zz:657zz:690zz:691zz:696zz:697zz:698zz:699zz',
                      alternate_script: :only)
to_field 'subject_other_search', extract_marc(%w[600 610 611 630 647 655 656 657 658 696 697 698 699].map do |c|
  "#{c}abcdefghijklmnopqrstuw"
end.join(':'), alternate_script: false) do |record, accumulator, context|
  accumulator.reject! { |v| v.start_with?('nomesh') }
  if items(record, context).any? { |item| item.library == 'LANE' }
    arr = []
    extract_marc('655a').call(record, arr, nil)
    accumulator.reject! { |v| arr.include? v }
  end
end
to_field 'vern_subject_other_search', extract_marc(%w[600 610 611 630 647 655 656 657 658 696 697 698 699].map do |c|
  "#{c}abcdefghijklmnopqrstuw"
end.join(':'), alternate_script: :only)
to_field 'subject_other_subvy_search', extract_marc(%w[600 610 611 630 647 650 651 654 655 656 657 658 690 691 696 697 698 699].map do |c|
  "#{c}vy"
end.join(':'), alternate_script: false)
to_field 'vern_subject_other_subvy_search', extract_marc(%w[600 610 611 630 647 650 651 654 655 656 657 658 690 691 696 697 698 699].map do |c|
  "#{c}vy"
end.join(':'), alternate_script: :only)
to_field 'subject_all_search', extract_marc(%w[600 610 611 630 647 648 650 651 652 653 654 655 656 657 658 662 690 691 696 697 698 699 795].map do |c|
  "#{c}#{ALPHABET}"
end.join(':'), alternate_script: false)
to_field 'vern_subject_all_search', extract_marc(%w[600 610 611 630 647 648 650 651 652 653 654 655 656 657 658 662 690 691 696 697 698 699 795].map do |c|
  "#{c}#{ALPHABET}"
end.join(':'), alternate_script: :only)

# Subject Facet Fields
to_field 'topic_facet',
         extract_marc('600abcdq:600t:610ab:610t:630a:630t:650a', alternate_script: false) do |_record, accumulator|
  accumulator.map! { |v| trim_punctuation_custom(v, /([\p{L}\p{N}]{4}|[A-Za-z]{3}|\))\. *\Z/) }
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.reject! { |v| v.start_with?('nomesh') }
end

to_field 'geographic_facet', extract_marc('651a', alternate_script: false) do |_record, accumulator|
  accumulator.map! { |v| v.gsub(/[\\,;]$/, '') }
  accumulator.map! { |v| v.gsub(/([A-Za-z0-9]{2}|\))[\\,;.]\.?\s*$/, '\1') }
end
to_field 'geographic_facet' do |record, accumulator|
  Traject::MarcExtractor.new((600...699).map do |x|
                               "#{x}z"
                             end.join(':'), alternate_script: false).collect_matching_lines(record) do |field, _spec, _extractor|
    accumulator << field['z'] if field['z'] # take only the first subfield z
  end

  accumulator.map! { |v| v.gsub(/[\\,;]$/, '') }
  accumulator.map! { |v| v.gsub(/([A-Za-z0-9]{2}|\))[\\,;.]\.?\s*$/, '\1') }
end

to_field 'era_facet', extract_marc('650y:651y:660y:661y', alternate_script: false) do |_record, accumulator|
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.map! { |v| trim_punctuation_custom(v, /([A-Za-z0-9]{2})\. *\Z/) }
end

# # Publication Fields

# 260ab and 264ab, without s.l in 260a and without s.n. in 260b
to_field 'pub_search' do |record, accumulator|
  Traject::MarcExtractor.new('260:264',
                             alternate_script: false).collect_matching_lines(record) do |field, _spec, _extractor|
    data = field.subfields.select { |x| x.code == 'a' || x.code == 'b' }
                .reject { |x| x.code == 'a' && (x.value =~ /s\.l\./i || x.value =~ /place of .* not identified/i) }
                .reject { |x| x.code == 'b' && (x.value =~ /s\.n\./i || x.value =~ /r not identified/i) }
                .map(&:value)

    unless data.empty?
      accumulator << trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff(data.join(' '))
    end
  end
end
to_field 'vern_pub_search', extract_marc('260ab:264ab', alternate_script: :only)
to_field 'pub_country', extract_marc('008') do |_record, accumulator|
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

             century_suffix = if %w[11 12 13].include? century_year
                                'th'
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

  year ||= Traject::MarcExtractor.new('260c:264c').to_enum(:collect_matching_lines,
                                                           record).map do |field, spec, extractor|
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
  year ||= Traject::MarcExtractor.new('264c', alternate_script: false).to_enum(:collect_matching_lines,
                                                                               record).map do |field, spec, extractor|
    next unless field.indicator2 == '1'

    extractor.collect_subfields(field, spec).map { |value| clean_date_string(value) }.first
  end.compact.first

  year ||= Traject::MarcExtractor.new('260c:264c', alternate_script: false).to_enum(:collect_matching_lines,
                                                                                    record).map do |field, spec, extractor|
    extractor.collect_subfields(field, spec).map { |value| clean_date_string(value) }.first
  end.compact.first

  # hyphens sort before 0, so the lexical sorting will be correct. I think.
  year ||= if f008_bytes7to10 =~ (/\d\d[u-][u-]/) && (record['008'].value[7..8] <= Time.now.year.to_s[0..1])
             "#{record['008'].value[7..8]}--"
           end

  # colons sort after 9, so the lexical sorting will be correct. I think.
  # NOTE: the solrmarc code has this comment, and yet still uses hyphens below; maybe a bug?
  year ||= if f008_bytes11to14 =~ (/\d\d[u-][u-]/) && (record['008'].value[11..12] <= Time.now.year.to_s[0..1])
             "#{record['008'].value[11..12]}--"
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
      if year_date1 && year_date2 && year_date2 != '9999'
        accumulator.concat(((year_date1.to_i)..(year_date2.to_i)).map(&:to_s))
      end
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
    Traject::MarcExtractor.new('260c',
                               alternate_script: false).collect_matching_lines(record) do |field, spec, extractor|
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
  Traject::MarcExtractor.new('008').collect_matching_lines(record) do |field, _spec, _extractor|
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

  imprint = Traject::MarcExtractor.new('2603abcefg',
                                       alternate_script: false).extract(record).uniq.map(&:strip).join(' ')
  vernImprint = Traject::MarcExtractor.new('2603abcefg',
                                           alternate_script: :only).extract(record).uniq.map(&:strip).join(' ')

  all_pub = Traject::MarcExtractor.new('2643abc', alternate_script: false).extract(record).uniq.map(&:strip)
  all_vernPub = Traject::MarcExtractor.new('2643abc', alternate_script: :only).extract(record).uniq.map(&:strip)

  bad_pub = Traject::MarcExtractor.new('264| 4|3abc:264|24|3abc:264|34|3abc',
                                       alternate_script: false).extract(record).uniq.map(&:strip)
  bad_vernPub = Traject::MarcExtractor.new('264| 4|3abc:264|24|3abc:264|34|3abc',
                                           alternate_script: :only).extract(record).uniq.map(&:strip)

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
to_field 'date_cataloged' do |record, accumulator|
  timestamp = record.instance['catalogedDate']
  begin
    accumulator << Time.parse(timestamp).utc.at_beginning_of_day.iso8601 if timestamp =~ /^\d{4}-\d{2}-\d{2}/
  rescue ArgumentError
    nil
  end
end

to_field 'language', extract_marc('008') do |_record, accumulator|
  translation_map = Traject::TranslationMap.new('marc_languages')
  accumulator.replace translation_map.translate_array(accumulator.map { |v| v[35..37] }).flatten
end

to_field 'language', extract_marc('041d:041e:041j') do |_record, accumulator|
  accumulator.map!(&:strip)
  translation_map = Traject::TranslationMap.new('marc_languages')
  accumulator.replace translation_map.translate_array(accumulator)
end

to_field 'language', extract_marc('041a') do |_record, accumulator|
  accumulator.map!(&:strip)
  translation_map = Traject::TranslationMap.new('marc_languages')
  accumulator.select! { |value|  (value.length % 3) == 0 }
  # using explicit block form to work around jruby bug: https://github.com/jruby/jruby/issues/7505
  codes = accumulator.flat_map { |value| value.length == 3 ? value : value.chars.each_slice(3).map { |x| x.join } }

  codes = codes.uniq
  translation_map.translate_array!(codes)
  accumulator.replace codes
end

#
# # URL Fields
# get full text urls from 856
# get all 956 subfield u containing fulltext urls that aren't SFX
to_field 'url_fulltext' do |record, accumulator|
  Traject::MarcExtractor.new('856u:956u', alternate_script: false).collect_matching_lines(record) do |field, spec, extractor|
    next unless MarcLinks::Processor.new(field).link_is_fulltext?

    accumulator.concat extractor.collect_subfields(field, spec)
  end

  accumulator.reject! { |v| v.blank? }
end

# returns the URLs for supplementary information (rather than fulltext)
to_field 'url_suppl' do |record, accumulator|
  Traject::MarcExtractor.new('856u').collect_matching_lines(record) do |field, spec, extractor|
    next unless MarcLinks::Processor.new(field).link_is_supplemental?

    accumulator.concat extractor.collect_subfields(field, spec)
  end
end

to_field 'url_sfx', extract_marc('956u') do |_record, accumulator|
  accumulator.select! { |v| MarcLinks::SFX_URL_REGEX.match?(v) }
end

# returns the URLs for restricted full text of a resource described
#  by the 856u.  Restricted is determined by matching a string against
#  the 856z.  ("available to stanford-affiliated users at:")
# or "Access restricted to Stanford community" for Lane.
to_field 'url_restricted' do |record, accumulator|
  Traject::MarcExtractor.new('856u').collect_matching_lines(record) do |field, spec, extractor|
    marc_link = MarcLinks::Processor.new(field)
    next unless marc_link.link_is_fulltext? && marc_link.stanford_only?

    accumulator.concat extractor.collect_subfields(field, spec)
  end
end

to_field 'marc_links_struct' do |record, accumulator|
  Traject::MarcExtractor.new('856').collect_matching_lines(record) do |field, _spec, _extractor|
    result = MarcLinks::Processor.new(field).as_h
    accumulator << result if result
  end
end

to_field 'marc_links_struct' do |record, accumulator|
  Traject::MarcExtractor.new('956').collect_matching_lines(record) do |field, _spec, _extractor|
    result = MarcLinks::Processor.new(field).as_h
    accumulator << result if result
  end
end

# Not using traject's oclcnum here because we have more complicated logic
to_field 'oclc' do |record, accumulator|
  marc035_with_m_suffix = []
  marc035_without_m_suffix = []
  Traject::MarcExtractor.new('035a', separator: nil).extract(record).map do |data|
    if data.start_with?('(OCoLC-M)')
      marc035_with_m_suffix << data.sub(/^\(OCoLC-M\)\s*(ocm|ocn|on)?\s*/, '')
    elsif data.start_with?('(OCoLC)')
      marc035_without_m_suffix << data.sub(/^\(OCoLC\)\s*(ocm|ocn|on)?\s*/, '')
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
  # E-resources are online
  accumulator << 'Online' if record.eresource?

  # Holdings that aren't electronic and aren't on-order must be at the library
  accumulator << 'At the Library' if items(record, context).any? { |item| item.status != 'On order' }

  # Actual on-order PO line
  accumulator << 'On order' if items(record, context).any? { |item| item.status == 'On order' }

  # Stub on-order records
  accumulator << 'On order' if accumulator.empty? && items(record, context).any? { |item| item.status == 'On order' }
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

            arr << 'Book' if %w[a m].include? record.leader[7]

            arr << 'Archive/Manuscript' if record.leader[7] == 'c'

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
to_field 'format_main_ssim' do |record, accumulator, _context|
  Traject::MarcExtractor.new('655a').collect_matching_lines(record) do |field, spec, extractor|
    accumulator << 'Dataset' if extractor.collect_subfields(field, spec).include? 'Data sets'
  end

  Traject::MarcExtractor.new('336a').collect_matching_lines(record) do |field, spec, extractor|
    if ['computer dataset', 'cartographic dataset'].any? { |v| extractor.collect_subfields(field, spec).include?(v) }
      accumulator << 'Dataset'
    end
  end
end

# Statistical code is 'Database'
to_field 'format_main_ssim' do |record, accumulator, _context|
  accumulator << 'Database' if record.statistical_codes.any? { |stat_code| stat_code['name'] == 'Database' }
end

to_field 'format_main_ssim' do |_record, _accumulator, context|
  # if it is a Database and a Software/Multimedia, and it is not
  #  "At the Library", then it should only be a Database
  if context.output_hash.fetch('format_main_ssim',
                               []).include?('Database') && context.output_hash['format_main_ssim'].include?('Software/Multimedia') && !Array(context.output_hash['access_facet']).include?('At the Library')
    context.output_hash['format_main_ssim'].delete('Software/Multimedia')
  end
end

# /* If the call number prefixes in the MARC 999a are for Archive/Manuscript items, add Archive/Manuscript format
#  * A (e.g. A0015), F (e.g. F0110), M (e.g. M1810), MISC (e.g. MISC 1773), MSS CODEX (e.g. MSS CODEX 0335),
#   MSS MEDIA (e.g. MSS MEDIA 0025), MSS PHOTO (e.g. MSS PHOTO 0463), MSS PRINTS (e.g. MSS PRINTS 0417),
#   PC (e.g. PC0012), SC (e.g. SC1076), SCD (e.g. SCD0012), SCM (e.g. SCM0348), and V (e.g. V0321).  However,
#   A, F, M, PC, and V are also in the Library of Congress classification which could be in the 999a, so need to make sure that
#   the call number type in the 999w == ALPHANUM and the library in the 999m == SPEC-COLL.
#  */
to_field 'format_main_ssim' do |record, accumulator, context|
  if items(record, context).any? do |item|
       item.library == 'SPEC-COLL' && item.call_number_type == 'ALPHANUM' && item.call_number.to_s =~ /^(A\d|F\d|M\d|MISC \d|(MSS (CODEX|MEDIA|PHOTO|PRINTS))|PC\d|SC[\d|DM]|V\d)/i
     end
    accumulator << 'Archive/Manuscript'
  end
end

to_field 'format_main_ssim' do |record, accumulator, context|
  if items(record, context).any? { |item| item.library == 'LANE' }
    Traject::MarcExtractor.new('245h').collect_matching_lines(record) do |field, spec, extractor|
      accumulator << 'Book' if extractor.collect_subfields(field, spec).join(' ') =~ /manuscript/
    end
  end
end

to_field 'format_main_ssim' do |record, accumulator, context|
  if items(record, context).any? do |item|
       item.library == 'LANE'
     end && ((record.leader[6] == 'a' || record.leader[6] == 't') && (record.leader[7] == 'c' || record.leader[7] == 'd'))
    context.output_hash.fetch('format_main_ssim', []).delete('Archive/Manuscript')
    accumulator << 'Book'
  end
end

to_field 'format_main_ssim' do |record, accumulator|
  Traject::MarcExtractor.new('590a', alternate_script: false).collect_matching_lines(record) do |field, spec, extractor|
    if extractor.collect_subfields(field, spec).any? { |x| x =~ /MARCit brief record/ }
      accumulator << 'Journal/Periodical'
    end
  end
end

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
  if items(record, context).any?(&:equipment?)
    context.output_hash['format_main_ssim']&.replace([])
    accumulator << 'Equipment'
  end
end

to_field 'format_main_ssim' do |record, accumulator, context|
  if context.output_hash['format_main_ssim'].nil? || context.output_hash['format_main_ssim'].include?('Other')
    format = Traject::MarcExtractor.new('245h',
                                        alternate_script: false).collect_matching_lines(record) do |field, spec, extractor|
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

to_field 'format_main_ssim' do |_record, _accumulator, context|
  next if context.output_hash['format_main_ssim'].nil?

  context.output_hash['format_main_ssim'].delete('Other') if context.output_hash['format_main_ssim']
end

# * INDEX-89 - Add video physical formats
to_field 'format_physical_ssim' do |record, accumulator, context|
  items(record, context).each do |item|
    call_number = item.call_number.to_s

    accumulator << 'Blu-ray' if call_number =~ /BLU-RAY/
    accumulator << 'Videocassette (VHS)' if call_number =~ Regexp.union(/ZVC/, /ARTVC/, /MVC/)
    accumulator << 'DVD' if call_number =~ Regexp.union(/ZDVD/, /ARTDVD/, /MDVD/, /ADVD/)
    accumulator << 'Videocassette' if call_number =~ /AVC/
    accumulator << 'Laser disc' if call_number =~ Regexp.union(/ZVD/, /MVD/)
  end
end

to_field 'format_physical_ssim', extract_marc('007') do |_record, accumulator, context|
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
          when 'b', 'c'
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
to_field 'format_physical_ssim', extract_marc('538a', alternate_script: false) do |_record, accumulator|
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
to_field 'format_physical_ssim', extract_marc('300b', alternate_script: false) do |_record, accumulator|
  accumulator.replace(accumulator.map do |value|
    case value
    when /MP4/
      'MPEG-4'
    when /VCD/, /Video CD/, /VideoCD/
      'Video CD'
    end
  end)
end

to_field 'format_physical_ssim', extract_marc('347b', alternate_script: false) do |_record, accumulator|
  accumulator.replace(accumulator.map do |value|
    case value
    when /MPEG-4/
      'MPEG-4'
    when /VCD/, /Video CD/, /VideoCD/
      'Video CD'
    end
  end)
end

to_field 'format_physical_ssim', extract_marc('300a:338a', alternate_script: false) do |_record, accumulator|
  accumulator.replace(accumulator.map do |value|
    case value
    when /audio roll/, /piano roll/, /organ roll/
      'Piano/Organ roll'
    end
  end)
end

to_field 'format_physical_ssim' do |record, accumulator, context|
  if items(record, context).any? { |item| item.call_number.to_s.start_with? 'MFICHE' }
    accumulator << 'Microfiche'
  end
  if items(record, context).any? { |item| item.call_number.to_s.start_with? 'MFILM' }
    accumulator << 'Microfilm'
  end
end

to_field 'format_physical_ssim', extract_marc("300#{ALPHABET}", alternate_script: false) do |_record, accumulator|
  values = accumulator.dup
  accumulator.replace([])

  values.each do |value|
    if value =~ (%r{(sound|audio) discs? (\((ca. )?\d+.*\))?\D+((digital|CD audio)\D*[,;.])? (c )?(4 3/4|12 c)}) && !(value =~ /(DVD|SACD|blu[- ]?ray)/)
      accumulator << 'CD'
    end

    accumulator << 'Vinyl disc' if value =~ (%r{33(\.3| 1/3) ?rpm}) && (value =~ /(10|12) ?in/)
  end
end

to_field 'characteristics_ssim' do |marc, accumulator|
  {
    '344' => 'Sound',
    '345' => 'Projection',
    '346' => 'Video',
    '347' => 'Digital'
  }.each do |tag, label|
    next unless marc[tag]

    characteristics_fields = String.new
    marc.find_all { |f| tag == f.tag }.each do |field|
      subfields = field.map do |subfield|
        subfield.value if ('a'..'z').include?(subfield.code) && !Constants::EXCLUDE_FIELDS.include?(subfield.code)
      end.compact.join('; ')
      characteristics_fields << "#{subfields}." unless subfields.empty?
    end

    accumulator << "#{label}: #{characteristics_fields}" unless characteristics_fields.empty?
  end
end

to_field 'format_physical_ssim', extract_marc('300a', alternate_script: false) do |_record, accumulator|
  values = accumulator.dup.join("\n")
  accumulator.replace([])

  accumulator << 'Microfiche' if values =~ /microfiche/i
  accumulator << 'Microfilm' if values =~ /microfilm/i
  accumulator << 'Photo' if values =~ /photograph/i
  accumulator << 'Remote-sensing image' if values =~ Regexp.union(/remote-sensing image/i, /remote sensing image/i)
  accumulator << 'Slide' if values =~ /slide/i
end

# look for thesis by existence of 502 field
to_field 'genre_ssim' do |record, accumulator|
  accumulator << 'Thesis/Dissertation' if record['502']
end

to_field 'genre_ssim', extract_marc('655av', alternate_script: false) do |_record, accumulator|
  # normalize values
  accumulator.map! do |v|
    previous_v = nil
    until v == previous_v
      previous_v = v
      v = v.strip.sub(/([\\,;:])+$/, '').sub(/([\p{L}\p{N}]{4}|\.*?[\s)]|[.{2,}]|[AMUaw][adir][cirt])\.$/, '\1').strip
    end
    v
  end

  accumulator.map!(&method(:clean_facet_punctuation))
end

to_field 'genre_ssim',
         extract_marc('600v:610v:611v:630v:647v:648v:650v:651v:654v:656v:657v',
                      alternate_script: false) do |_record, accumulator|
  # normalize values
  accumulator.map! do |v|
    previous_v = nil
    until v == previous_v
      previous_v = v
      v = v.strip.sub(/([\\,;:])+$/, '').sub(/([\p{L}\p{N}]{4}|\.*?[\s)]|[.{2,}]|[AMUaw][adir][cirt])\.$/, '\1').strip
    end
    v
  end

  accumulator.map!(&method(:clean_facet_punctuation))
end

#  look for conference proceedings in 6xx sub x or v
to_field 'genre_ssim' do |record, accumulator|
  f600xorvspec = (600..699).flat_map { |x| ["#{x}x", "#{x}v"] }
  Traject::MarcExtractor.new(f600xorvspec).collect_matching_lines(record) do |field, spec, extractor|
    accumulator << 'Conference proceedings' if extractor.collect_subfields(field, spec).any? { |x| x =~ /congresses/i }
  end
end

# Based upon SW-1056, added the following to the algorithm to determine if something is a conference proceeding:
# Leader/07 = 'm' or 's' and 008/29 = '1'
to_field 'genre_ssim' do |record, accumulator|
  if (record.leader[7] == 'm' || record.leader[7] == 's') && (record['008'] && record['008'].value[29] == '1')
    accumulator << 'Conference proceedings'
  end
end

# /** Based upon SW-1489, if the record is for a certain format (MARC, MRDF,
#  *  MAP, SERIAL, or VM and not SCORE, RECORDING, and MANUSCRIPT) and it has
#  *  something in the 008/28 byte, I’m supposed to give it a genre type of
#  *  government document
# **/
to_field 'genre_ssim' do |record, accumulator, context|
  next if (context.output_hash['format_main_ssim'] || []).include? 'Archive/Manuscript'
  next if (context.output_hash['format_main_ssim'] || []).include? 'Music score'
  next if (context.output_hash['format_main_ssim'] || []).include? 'Music recording'

  accumulator << 'Government document' if record['008'] && record['008'].value[28] && record['008'].value[28] =~ /[a-z]/
end

# /** Based upon SW-1506 - add technical report as a genre if
#  *  leader/06: a or t AND 008/24-27 (any position, i.e. 24, 25, 26, or 27): t
#  *    OR
#  *  Presence of 027 OR 088
#  *    OR
#  *  006/00: a or t AND 006/7-10 (any position, i.e. 7, 8, 9, or 10): t
# **/
to_field 'genre_ssim' do |record, accumulator|
  if record['008'] && record['008'].value.length >= 28
    if (record.leader[6] == 'a' || record.leader[6] == 't') && record['008'].value[24..27] =~ /t/
      accumulator << 'Technical report'
    end
  elsif record['027'] || record['088']
    accumulator << 'Technical report'
  elsif record['006'] && (record['006'].value[0] == 'a' || record['006'].value[0] == 't') && record['006'].value[7..10] =~ /t/
    accumulator << 'Technical report'
  end
end

to_field 'db_az_subject', extract_marc('099a') do |_record, accumulator, context|
  if context.output_hash['format_main_ssim'] && context.output_hash['format_main_ssim'].include?('Database')
    translation_map = Traject::TranslationMap.new('db_subjects_map')
    accumulator.replace translation_map.translate_array(accumulator).flatten
  else
    accumulator.replace([])
  end
end

to_field 'db_az_subject' do |record, accumulator, context|
  if context.output_hash['format_main_ssim'] && context.output_hash['format_main_ssim'].include?('Database') && record['099'].nil?
    accumulator << 'Uncategorized'
  end
end

to_field 'physical', extract_marc('3003abcefg', alternate_script: false)
to_field 'vern_physical', extract_marc('3003abcefg', alternate_script: :only)

to_field 'toc_search', extract_marc('905art:505art', alternate_script: false)
to_field 'vern_toc_search', extract_marc('505art', alternate_script: :only)

# sometimes we find vernacular script in the 505 anyway :shrug:
to_field 'vern_toc_search' do |_record, accumulator, context|
  next unless context.output_hash['toc_search']

  accumulator.replace(context.output_hash['toc_search'].select { |value| value.match?(CJK_RANGE) })
end

# Generate structured data from the table of contents (IE marc 505 + 905s).
# There are arrays of values for each TOC entry, and each TOC contains e.g. a chapter title; e.g.:
#  - fields: [['Vol 1 Chapter 1', 'Vol 1 Chapter 2'], ['Vol 2 Chapter 1']]
#    vernacular: [['The same, but pulled from the matched vernacular fields']]
#    unmatched_vernacular: [['The same, but pulled from any unmatched vernacular fields']]
to_field 'toc_struct' do |marc, accumulator|
  fields = []
  vern = []
  unmatched_vern = []
  label = 'Contents'

  tag = '905' if marc['905'] && (marc['505'].nil? or (marc['505']['t'].nil? and marc['505']['r'].nil?))
  tag ||= '505'

  if marc['505'] or marc['905']
    marc.find_all { |f| tag == f.tag }.each do |field|
      data = []
      buffer = []
      field.each do |sub_field|
        if sub_field.code == 'a'
          data << buffer.map { |w| w.strip unless w.strip.empty? }.compact.join(' ') if buffer.any?
          buffer = []
          chapters = split_toc_chapters(sub_field.value)
          if chapters.length > 1
            data.concat(chapters)
          else
            data.concat([sub_field.value])
          end
        elsif sub_field.code == '1' && !Constants::SOURCES[sub_field.value.strip].nil?
          data << buffer.map { |w| w.strip unless w.strip.empty? }.compact.join(' ') if buffer.any?
          buffer = []
          data << Constants::SOURCES[sub_field.value.strip]
        elsif !(Constants::EXCLUDE_FIELDS + ['x']).include?(sub_field.code)
          # we could probably just do /\s--\s/ but this works so we'll stick w/ it.
          if sub_field.value =~ /[^\S]--\s*$/
            buffer << sub_field.value.sub(/[^\S]--\s*$/, '')
            data << buffer.map { |w| w.strip unless w.strip.empty? }.compact.join(' ')
            buffer = []
          else
            buffer << sub_field.value
          end
        end
      end

      label = 'Partial contents' if field.indicator1 == '1' || field.indicator1 == '2'

      data << buffer.map { |w| w.strip unless w.strip.empty? }.compact.join(' ') unless buffer.empty?
      fields << data

      vernacular = get_marc_vernacular(marc, field)
      vern << split_toc_chapters(vernacular).map { |w| w.strip unless w.strip.empty? }.compact unless vernacular.nil?
    end
  end

  unmatched_vern_fields = get_unmatched_vernacular(marc, '505')
  unmatched_vern_fields.each do |vern_field|
    unmatched_vern << vern_field.split(/[^\S]--[^\S]/).map { |w| w.strip unless w.strip.empty? }.compact
  end

  new_vern = vern unless vern.empty?
  new_fields = fields unless fields.empty?
  new_unmatched_vern = unmatched_vern unless unmatched_vern.empty?
  accumulator << { label:, fields: new_fields, vernacular: new_vern,
                   unmatched_vernacular: new_unmatched_vern } unless new_fields.nil? and new_vern.nil? and new_unmatched_vern.nil?
end

to_field 'summary_struct' do |marc, accumulator|
  summary(marc, accumulator)
  content_advice(marc, accumulator)
end

def summary(marc, accumulator)
  tag = marc['920'] ? '920' : '520'
  label = if marc['920']
            "Publisher's summary"
          else
            'Summary'
          end
  matching_fields = marc.find_all do |f|
    if tag == '520'
      f.tag == tag && f.indicator1 != '4'
    else
      f.tag == tag
    end
  end

  accumulate_summary_struct_fields(matching_fields, tag, label, marc, accumulator)
end

def content_advice(marc, accumulator)
  tag = '520'
  label = 'Content advice'
  matching_fields = marc.find_all do |f|
    f.tag == tag && f.indicator1 == '4'
  end

  accumulate_summary_struct_fields(matching_fields, tag, label, marc, accumulator)
end

def accumulate_summary_struct_fields(matching_fields, tag, label, marc, accumulator)
  fields = []
  unmatched_vern = []
  if matching_fields.any?
    matching_fields.each do |field|
      field_text = []
      field.each do |sub_field|
        if sub_field.code == 'u' and sub_field.value.strip =~ %r{^https*://}
          field_text << { link: sub_field.value }
        elsif sub_field.code == '1'
          field_text << { source: Constants::SOURCES[sub_field.value] }
        elsif !(Constants::EXCLUDE_FIELDS + ['x']).include?(sub_field.code)
          field_text << sub_field.value unless sub_field.code == 'a' && sub_field.value[0, 1] == '%'
        end
      end
      fields << { field: field_text, vernacular: get_marc_vernacular(marc, field) } unless field_text.empty?
    end
  else
    unmatched_vern = get_unmatched_vernacular(marc, tag)
  end

  accumulator << { label:, fields:,
                   unmatched_vernacular: unmatched_vern } if !fields.empty? || !unmatched_vern.empty?
end

to_field 'context_search', extract_marc('518a', alternate_script: false)
to_field 'vern_context_search', extract_marc('518aa', alternate_script: :only)
to_field 'summary_search', extract_marc('920ab:520ab', alternate_script: false)
to_field 'vern_summary_search', extract_marc('520ab', alternate_script: :only)

# sometimes we find vernacular script in the 520 anyway :shrug:
to_field 'vern_summary_search' do |_record, accumulator, context|
  next unless context.output_hash['summary_search']

  accumulator.replace(context.output_hash['summary_search'].select { |value| value.match?(CJK_RANGE) })
end

to_field 'award_search', extract_marc('986a:586a', alternate_script: false)

# # Standard Number Fields
to_field 'isbn_search',
         extract_marc(
           '020a:020z:770z:771z:772z:773z:774z:775z:776z:777z:778z:779z:780z:781z:782z:783z:784z:785z:786z:787z:788z:789z', alternate_script: false
         ) do |_record, accumulator|
  accumulator.map!(&method(:extract_isbn))
end

# # Added fields for searching based upon list from Kay Teel in JIRA ticket INDEX-142
to_field 'issn_search',
         extract_marc(
           '022a:022l:022m:022y:022z:400x:410x:411x:440x:490x:510x:700x:710x:711x:730x:760x:762x:765x:767x:770x:771x:772x:773x:774x:775x:776x:777x:778x:779x:780x:781x:782x:783x:784x:785x:786x:787x:788x:789x:800x:810x:811x:830x',
           alternate_script: false
         ) do |_record, accumulator|
  accumulator.map!(&:strip)
  accumulator.select! { |v| v =~ issn_pattern }
end

to_field 'isbn_display', extract_marc('020a', alternate_script: false) do |_record, accumulator|
  accumulator.map!(&method(:extract_isbn))
end

to_field 'isbn_display' do |record, accumulator, context|
  next unless context.output_hash['isbn_display'].nil?

  marc020z = Traject::MarcExtractor.new('020z', alternate_script: false).extract(record)
  accumulator.concat marc020z.map(&method(:extract_isbn))
end

to_field 'issn_display', extract_marc('022a', alternate_script: false) do |_record, accumulator|
  accumulator.map!(&:strip)
  accumulator.select! { |v| v =~ issn_pattern }
end

to_field 'issn_display' do |record, accumulator, context|
  next if context.output_hash['issn_display']

  marc022z = Traject::MarcExtractor.new('022z', alternate_script: false).extract(record).map(&:strip)
  accumulator.concat(marc022z.select { |v| v =~ issn_pattern })
end

to_field 'lccn', extract_marc('010a', first: true) do |_record, accumulator|
  accumulator.map!(&:strip)
  lccn_pattern = %r{^(([ a-z]{3}\d{8})|([ a-z]{2}\d{10})) ?|( /.*)?$}
  accumulator.select! { |x| x =~ lccn_pattern }

  accumulator.map! do |value|
    value.gsub(lccn_pattern, '\1')
  end
end

to_field 'lccn', extract_marc('010z', first: true) do |_record, accumulator, context|
  accumulator.map!(&:strip)
  accumulator.replace([]) and next unless context.output_hash['lccn'].nil?

  lccn_pattern = %r{^(([ a-z]{3}\d{8})|([ a-z]{2}\d{10})) ?|( /.*)?$}
  accumulator.select! { |x| x =~ lccn_pattern }

  accumulator.map! do |value|
    value.gsub(lccn_pattern, '\1')
  end
end

#
# # Call Number Fields

# For LC call numbers
to_field 'callnum_facet_hsim' do |record, accumulator, context|
  items(record, context).each do |item|
    next if item.skipped? ||
            item.call_number.type != 'LC'

    translation_map = Traject::TranslationMap.new('call_number')
    cn = item.call_number.classification
    next unless cn && cn.start_with?(/[A-Z]/)

    first_letter = cn[0, 1].upcase
    letters = cn[/^[A-Z]+/]

    next unless first_letter && translation_map[first_letter]

    accumulator << [
      'LC Classification',
      translation_map[first_letter],
      translation_map[letters]
    ].compact.join('|')
  end
end

# For Dewey call numbers, or ones that are coded as LC, but are infact valid Dewey
to_field 'callnum_facet_hsim' do |record, accumulator, context|
  items(record, context).each do |item|
    next if item.skipped? ||
            item.call_number.type != 'DEWEY'

    cn = item.call_number.classification
    next unless cn && cn.start_with?(/\d{2}/)

    first_digit = "#{cn[0, 1]}00s"
    two_digits = "#{cn[0, 2]}0s"

    translation_map = Traject::TranslationMap.new('call_number')

    accumulator << [
      'Dewey Classification',
      translation_map[first_digit],
      translation_map[two_digits]
    ].compact.join('|')
  end

  accumulator.uniq!
end

# For MARC 050 LC Classification
to_field 'callnum_facet_hsim', extract_marc('050ab') do |record, accumulator, context|
  accumulator.replace([]) and next if context.output_hash['callnum_facet_hsim'] || (record['086'] || {})['a']

  accumulator.map! do |cn|
    next unless cn =~ FolioItem::CallNumber::VALID_LC_REGEX

    first_letter = cn[0, 1].upcase
    letters = cn[/^[A-Z]+/]

    translation_map = Traject::TranslationMap.new('call_number')

    next unless first_letter && translation_map[first_letter]

    [
      'LC Classification',
      translation_map[first_letter],
      translation_map[letters]
    ].compact.join('|')
  end

  accumulator.replace([accumulator.compact.first])
end

# For locally assigned LC (MARC 090)
to_field 'callnum_facet_hsim', extract_marc('090ab') do |record, accumulator, context|
  accumulator.replace([]) and next if context.output_hash['callnum_facet_hsim'] || (record['086'] || {})['a']

  accumulator.map! do |cn|
    next unless cn =~ FolioItem::CallNumber::VALID_LC_REGEX

    first_letter = cn[0, 1].upcase
    letters = cn[/^[A-Z]+/]

    translation_map = Traject::TranslationMap.new('call_number')

    next unless first_letter && translation_map[first_letter]

    [
      'LC Classification',
      translation_map[first_letter],
      translation_map[letters]
    ].compact.join('|')
  end

  accumulator.replace([accumulator.compact.first])
end

# Gov docs value based on location details
to_field 'callnum_facet_hsim' do |record, accumulator, _context|
  gov_doc_values = record.items.filter_map do |item|
    item.dig('location', 'effectiveLocation', 'details', 'searchworksGovDocsClassification')
  end

  gov_doc_values.uniq.each do |gov_doc_value|
    accumulator << ['Government Document', gov_doc_value].join('|')
  end
end

# Gov docs value based on marc 086
to_field 'callnum_facet_hsim' do |record, accumulator, context|
  marc_086 = record.fields('086')

  next if context.output_hash['callnum_facet_hsim']&.any? { |x| x.start_with?('Government Document|') } || marc_086.none?

  gov_doc_values = []
  marc_086.each do |marc_field|
    gov_doc_values << if marc_field.indicator1 == '0'
                        'Federal'
                      else
                        'Other'
                      end

    gov_doc_values.uniq.each do |gov_doc_value|
      accumulator << ['Government Document', gov_doc_value].join('|')
    end
  end
end

# Gov docs value based on SUDOC call number scheme
to_field 'callnum_facet_hsim' do |record, accumulator, context|
  next if context.output_hash['callnum_facet_hsim']&.any? { |x| x.start_with?('Government Document|') }

  if items(record, context).any? { |x| x.call_number_type == 'SUDOC' }
    accumulator << 'Government Document|Other'
  end
end

to_field 'callnum_search' do |record, accumulator, context|
  good_call_numbers = []
  items(record, context).each do |item|
    next if item.skipped?
    next if item.call_number.ignored_call_number? ||
            item.call_number.bad_lc_lane_call_number?

    call_number = item.call_number.to_s

    if item.call_number_type == 'DEWEY' || item.call_number_type == 'LC'
      call_number = call_number.strip
      call_number = call_number.gsub(/\s\s+/, ' ') # reduce multiple whitespace chars to a single space
      call_number = call_number.gsub('. .', ' .') # reduce multiple whitespace chars to a single space
      call_number = call_number.gsub(/(\d+\.) ([A-Z])/, '\1\2') # remove space after a period if period is after digits and before letters
      call_number = call_number.gsub(/\s*\.$/, '') # remove trailing period and any spaces before it
    end

    good_call_numbers << call_number
  end

  accumulator.concat(good_call_numbers.uniq)
end

to_field 'lc_assigned_callnum_ssim', extract_marc('050ab:090ab') do |_record, accumulator, _context|
  accumulator.select! { |cn| cn =~ FolioItem::CallNumber::VALID_LC_REGEX }
end

#
# # Location facet
to_field 'location_facet' do |record, accumulator, context|
  if items(record, context).any? { |item| item.display_location_code == 'EDU-CURRICULUM' }
    accumulator << 'Curriculum Collection'
  end

  if items(record, context).any? do |item|
       item.display_location_code =~ /^ART-LOCKED/ || item.display_location_code == 'SAL3-PAGE-AR'
     end
    accumulator << 'Art Locked Stacks'
  end
end

# # Stanford student work facet
# Get hierarchical values if 502 field contains "Stanford"
#  Thesis/Dissertation:
#    "Thesis/Dissertation|Degree level|Degree"
#      e.g. "Thesis/Dissertation|Master's|Engineer"
#      e.g. "Thesis/Dissertation|Doctoral|Doctor of Education (EdD)"
#
#  it is expected that these values will go to a field analyzed with
#   solr.PathHierarchyTokenizerFactory  so a value like
#    "Thesis/Dissertation|Master's|Engineer"
#  will be indexed as 3 values:
#    "Thesis/Dissertation|Master's|Engineer"
#    "Thesis/Dissertation|Master's"
#    "Thesis/Dissertation"
to_field 'stanford_work_facet_hsim' do |record, accumulator|
  Traject::MarcExtractor.cached('502').collect_matching_lines(record) do |field, spec, extractor|
    str = extractor.collect_subfields(field, spec).join(' ').downcase
    if str =~ /(.*)[Ss]tanford(.*)/
      degree = case str
               when /^thesis\s?.?b\.?\s?a\.?\s?(.*)/
                 'Thesis/Dissertation|Bachelor\'s|Bachelor of Arts (BA)'
               when /(.*)d\.?\s?m\.?\s?a\.?(.*)/
                 'Thesis/Dissertation|Doctoral|Doctor of Musical Arts (DMA)'
               when /(.*)ed\.?\s?d\.?(.*)/
                 'Thesis/Dissertation|Doctoral|Doctor of Education (EdD)'
               when /(.*)ed\.?\s?m\.?(.*)/
                 'Thesis/Dissertation|Master\'s|Master of Education (EdM)'
               when /(.*)(eng[^l]{1,}\.?r?\.?)(.*)/
                 'Thesis/Dissertation|Master\'s|Engineer'
               when /(.*)j\.?\s?d\.?(.*)/
                 'Thesis/Dissertation|Doctoral|Doctor of Jurisprudence (JD)'
               when /(.*)j\.?\s?s\.?\s?d\.?(.*)/
                 'Thesis/Dissertation|Doctoral|Doctor of the Science of Law (JSD)'
               when /(.*)j\.?\s?s\.?\s?m\.?(.*)/
                 'Thesis/Dissertation|Master\'s|Master of the Science of Law (JSM)'
               when /(.*)l\.?\s?l\.?\s?m\.?(.*)/
                 'Thesis/Dissertation|Master\'s|Master of Laws (LLM)'
               # periods between letters NOT optional else "masters" or "drama" matches
               when /(.*)\s?.?a\.\s?m\.\s?(.*)/, /(.*)m\.\s?a[.)]\s?(.*)/, /(.*)m\.\s?a\.?\s?(.*)/
                 'Thesis/Dissertation|Master\'s|Master of Arts (MA)'
               when /^thesis\s?.?m\.\s?d\.\s?(.*)/
                 'Thesis/Dissertation|Doctoral|Doctor of Medicine (MD)'
               when /(.*)m\.?\s?f\.?\s?a\.?(.*)/
                 'Thesis/Dissertation|Master\'s|Master of Fine Arts (MFA)'
               when /(.*)m\.?\s?l\.?\s?a\.?(.*)/
                 'Thesis/Dissertation|Master\'s|Master of Liberal Arts (MLA)'
               when /(.*)m\.?\s?l\.?\s?s\.?(.*)/
                 'Thesis/Dissertation|Master\'s|Master of Legal Studies (MLS)'
               # periods between letters NOT optional else "programs" matches
               when /(.*)m\.\s?s\.(.*)/, /master of science/
                 'Thesis/Dissertation|Master\'s|Master of Science (MS)'
               when /(.*)ph\s?\.?\s?d\.?(.*)/
                 'Thesis/Dissertation|Doctoral|Doctor of Philosophy (PhD)'
               when /student report/
                 'Other student work|Student report'
               when /(.*)honor'?s?(.*)(thesis|project)/, /(thesis|project)(.*)honor'?s?(.*)/
                 'Thesis/Dissertation|Bachelor\'s|Undergraduate honors thesis'
               when /(doctoral|graduate school of business)/
                 'Thesis/Dissertation|Doctoral|Unspecified'
               when /(.*)master'?s(.*)/
                 'Thesis/Dissertation|Master\'s|Unspecified'
               else
                 'Thesis/Dissertation|Unspecified'
               end
      accumulator << degree
    end
  end
end

# Get facet values for Stanford school and departments
# Only if record is for a Stanford thesis or dissertation
# Returns first 710b if 710a contains "Stanford"
# Returns 710a if it contains "Stanford" and no subfield b
# Replaces "Dept." with "Department" and cleans up punctuation
to_field 'stanford_dept_sim' do |record, accumulator, context|
  if context.output_hash['stanford_work_facet_hsim']&.any?
    Traject::MarcExtractor.cached('710ab').collect_matching_lines(record) do |field, _spec, _extractor|
      sub_a ||= field['a']
      sub_b ||= field['b']
      if sub_a =~ /stanford/i
        if sub_b.nil? # subfield b does not exist, subfield a is Stanford
          accumulator << sub_a
        else # subfield b exists
          sub_b = sub_b.strip # could contain just whitespace
          accumulator << if sub_b.empty?
                           sub_a
                         else
                           sub_b
                         end
        end
      end
    end
  end

  accumulator.map!(&method(:trim_punctuation_custom))
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.replace(accumulator.map do |value|
    value.gsub('Dept.', 'Department')
      .gsub(/([\p{L}\p{N}]{4}|\.*?[\s)]|[.{2,}]|[LAE][arn][wtg])\.$/, '\1')
  end)
end
#
# # Item Info Fields
to_field 'barcode_search' do |record, accumulator, context|
  context.output_hash['barcode_search'] = []

  items(record, context).each do |item|
    accumulator << item.barcode
  end
end

# * @return the barcode for the item to be used as the default choice for
# *  nearby-on-shelf display (i.e. when no particular item is selected by
# * preferred item algorithm, per INDEX-153:
# * 1. If Green item(s) have shelfkey, do this:
# * - pick the LC truncated callnum with the most items
# * - pick the shortest LC untruncated callnum if no truncation
# * - if no LC, got through callnum scheme order of preference:  LC, Dewey, Sudoc, Alphanum (without box and folder)
# * 2. If no Green shelfkey, use the above algorithm libraries (raw codes in 999) in alpha order.
# *
to_field 'preferred_barcode' do |record, accumulator, context|
  serial = (context.output_hash['format_main_ssim'] || []).include?('Journal/Periodical')
  non_skipped_items = items(record, context).sort_by(&:call_number).reject do |item|
    item.skipped? || item.call_number.bad_lc_lane_call_number? || item.call_number.ignored_call_number?
  end

  next if non_skipped_items.length == 0

  if non_skipped_items.length == 1
    accumulator << non_skipped_items.first.barcode
    next
  end

  # Prefer GREEN home library, and then any other location prioritized by library code
  items_by_library = non_skipped_items.group_by { |x| x.library }
  chosen_items = items_by_library['GREEN'] || items_by_library[items_by_library.keys.compact.sort.first]

  # Prefer LC over Dewey over SUDOC over Alphanum over Other call number types
  chosen_items_by_callnumber_type = chosen_items.group_by(&:call_number_type)
  preferred_callnumber_scheme_items = chosen_items_by_callnumber_type['LC'] ||
                                      chosen_items_by_callnumber_type['DEWEY'] ||
                                      chosen_items_by_callnumber_type['SUDOC'] ||
                                      chosen_items_by_callnumber_type['ALPHANUM'] ||
                                      chosen_items_by_callnumber_type.values.first

  preferred_callnumber_items_by_call_number = preferred_callnumber_scheme_items.group_by do |item|
    item.call_number.base_call_number
  end

  # Prefer the items with the most item for the lopped call number
  callnumber_with_the_most_items = preferred_callnumber_items_by_call_number.max_by { |_k, v| v.length }.last

  # If there's a tie, prefer the one with the shortest call number
  checking_for_ties_items = preferred_callnumber_items_by_call_number.select do |_k, v|
    v.length == callnumber_with_the_most_items.length
  end
  callnumber_with_the_most_items = checking_for_ties_items.min_by do |lopped_call_number, _items|
    lopped_call_number.length
  end.last if checking_for_ties_items.length > 1

  # Prefer items with the first volume sort key

  item_with_the_most_recent_shelfkey = callnumber_with_the_most_items.min_by do |item|
    [item.call_number.shelfkey(serial:).forward, item.barcode || '']
  end

  accumulator << item_with_the_most_recent_shelfkey.barcode
end

to_field 'holdings_library_code_ssim' do |record, accumulator|
  accumulator.concat(record.holdings.map { |holding| holding.dig('location', 'effectiveLocation', 'library', 'code') }.uniq)
end

to_field 'library_code_facet_ssim' do |record, accumulator, context|
  items(record, context).reject(&:skipped?).each do |item|
    next unless item.display_location&.dig('library')

    accumulator << item.display_location.dig('library', 'code')
    accumulator.concat item.display_location.dig('details', 'searchworksAdditionalLibraryCodeFacetValues')&.split(',')&.map(&:strip) || []
  end
end

to_field 'location_code_facet_ssim' do |record, accumulator, context|
  items(record, context).reject(&:skipped?).each do |item|
    accumulator << item.display_location_code
  end
end

to_field 'building_facet' do |record, accumulator, context|
  items(record, context).each do |item|
    next if item.skipped?

    accumulator << item.library
    # https://github.com/sul-dlss/solrmarc-sw/issues/101
    # Per Peter Blank - items with library = SAL3 and home location = PAGE-AR
    # should be given two library facet values:
    # SAL3 (off-campus storage) <- they are currently getting this
    # and Art & Architecture (Bowes) <- new requirement
    accumulator << 'ART' if item.display_location_code == 'SAL3-PAGE-AR'
  end

  accumulator.replace LibrariesMap.translate_array(accumulator)
end

to_field 'building_facet' do |record, accumulator|
  next if record.index_items.any?

  eholdings = record.holdings.select { |holding| holding.dig('holdingsType', 'name') == 'Electronic' || holding.dig('location', 'effectiveLocation', 'details', 'holdingsTypeName') == 'Electronic' }
  accumulator.concat(eholdings.map { |holding| LibrariesMap.for(holding.dig('location', 'effectiveLocation', 'library', 'code')) }.uniq)
end

to_field 'building_facet' do |record, accumulator|
  Traject::MarcExtractor.new('856u').collect_matching_lines(record) do |field, _spec, _extractor|
    accumulator << 'Stanford Digital Repository' if field['x'] =~ /SDR-PURL/ || field['u'] =~ /purl\.stanford\.edu/
  end
end

to_field 'building_location_facet_ssim' do |record, accumulator, context|
  items(record, context).each do |item|
    next if item.skipped?

    accumulator << [item.library, '*'].join('/')
    accumulator << [item.library, item.display_location_code].join('/')
    accumulator << [item.library, '*', 'type', item.type].join('/')
    accumulator << [item.library, item.display_location_code, 'type', item.type].join('/')
    next unless item.temporary_location_code

    accumulator << [item.library, '*', 'type', item.type, 'curr', item.temporary_location_code].join('/')
    accumulator << [item.library, '*', 'type', '*', 'curr', item.temporary_location_code].join('/')
    accumulator << [item.library, item.display_location_code, 'type', '*', 'curr', item.temporary_location_code].join('/')
    accumulator << [item.library, item.display_location_code, 'type', item.type, 'curr',
                    item.temporary_location_code].join('/')
  end
end

to_field 'item_display_struct' do |record, accumulator, context|
  serial = (context.output_hash['format_main_ssim'] || []).include?('Journal/Periodical')

  items(record, context).each do |item|
    next if item.skipped?

    call_number = item.call_number.to_s
    volume_sort = item.call_number.shelfkey(serial:).forward
    lopped_call_number = item.call_number.base_call_number

    if item.shelved_by_location?
      shelved_by_text = if [item.display_location_code, item.temporary_location_code].include? 'SCI-SHELBYSERIES'
                          'Shelved by Series title'
                        else
                          'Shelved by title'
                        end

      call_number = [shelved_by_text, item.call_number.volume_info].compact.join(' ')
    end

    call_number_data = if item.call_number.ignored_call_number?
                         {
                           callnumber: call_number
                         }
                       else
                         {
                           lopped_callnumber: lopped_call_number,
                           callnumber: call_number,
                           full_shelfkey: volume_sort
                         }
                       end

    accumulator << item.to_item_display_hash.merge(call_number_data)
  end
end

# Each (browseable) base call number is represented by a single browse nearby entry; we choose
# the representative item by the following rules:
# 1. If there's only one item with the base call number, then we use that item
# 2. For a serial publication, choose the latest item (e.g. V.57 2023 instead of V.34 2019)
# 3. For non-serial publications, choose the earliest item (e.g. V.1 instead of V.57)
#
# The earliest/latest logic is already baked into the full shelfkey.
to_field 'browse_nearby_struct' do |record, accumulator, context|
  serial = (context.output_hash['format_main_ssim'] || []).include?('Journal/Periodical')
  grouped_items = items(record, context)
                  .reject(&:skipped?)
                  .select { |item| item.call_number.to_s.present? && %w[LC DEWEY ALPHANUM].include?(item.call_number.type) }
                  .group_by { |item| item.call_number.base_call_number }

  browseable_items = grouped_items.map do |_base_call_number, items|
    if items.one?
      items.first
    else
      items.min_by { |item| item.call_number.shelfkey(serial:).forward }
    end
  end

  accumulator.concat(browseable_items.map do |item|
    shelfkey_obj = item.call_number.shelfkey(serial:)

    {
      lopped_callnumber: item.call_number.base_call_number,
      shelfkey: shelfkey_obj.forward,
      reverse_shelfkey: shelfkey_obj.reverse,
      callnumber: item.call_number.to_s,
      scheme: item.call_number.type.upcase,
      item_id: item.id
    }
  end)
end

# Inject a special browse nearby entry for e-resources, using either the call number from the holdings record
# or from the MARC data.
to_field 'browse_nearby_struct' do |record, accumulator, context|
  next if !record.eresource? || context.output_hash['browse_nearby_struct'].present?

  # Also exclude the browseable call number if we had items (with a call number) that we skipped because they
  # weren't the right type (e.g. SUDOC)
  next if items(record, context)
          .reject(&:skipped?)
          .any? { |item| item.call_number.to_s.present? && !%w[LC DEWEY ALPHANUM].include?(item.call_number.type) }

  callnumber = begin
    holding = record.electronic_holdings.first
    value = holding&.dig('callNumber')
    type = FolioItem.call_number_type_code(holding&.dig('callNumberType', 'name'))
    FolioItem::CallNumber.new(value, type) if value.present? && %w[LC DEWEY ALPHANUM].include?(type&.upcase)
  end

  callnumber ||= Traject::MarcExtractor.cached('050ab:090ab', alternate_script: false).extract(record).filter_map do |item_050|
    cn = FolioItem::CallNumber.new(item_050, 'LC')

    cn if cn.valid_lc?
  end.first

  next unless callnumber.present? && %w[LC DEWEY ALPHANUM].include?(callnumber.type.upcase)

  accumulator << {
    lopped_callnumber: callnumber.base_call_number,
    shelfkey: callnumber.shelfkey.forward,
    reverse_shelfkey: callnumber.shelfkey.reverse,
    callnumber: callnumber.call_number,
    scheme: callnumber.type.upcase
  }
end

to_field 'shelfkey' do |_record, accumulator, context|
  accumulator.concat context.output_hash['browse_nearby_struct']&.map { |v| v[:shelfkey] }&.compact || []
end

# given a shelfkey (a lexicaly sortable call number), return the reverse
# shelf key - a sortable version of the call number that will give the
# reverse order (for getting "previous" call numbers in a list)
#
# return the reverse String value, mapping A --> 9, B --> 8, ...
#   9 --> A and also non-alphanum to sort properly (before or after alphanum)
to_field 'reverse_shelfkey' do |_record, accumulator, context|
  accumulator.concat context.output_hash['browse_nearby_struct']&.map { |v| v[:reverse_shelfkey] }&.compact || []
end

##
# Skip records for missing `item_display` field
each_record do |_record, context|
  if context.output_hash['item_display_struct'].blank? && context.output_hash['marc_links_struct'].blank? && settings['skip_empty_item_display'] > -1
    context.skip!('No item_display_struct or marc_links_struct field')
  end
end

to_field 'mhld_display' do |record, accumulator, _context|
  record.mhld.each { |holding| accumulator << holding }
end

to_field 'bookplates_display' do |record, accumulator|
  Traject::MarcExtractor.new('979').collect_matching_lines(record) do |field, _spec, _extractor|
    file = field['c']
    next if file =~ /no content metadata/i

    fund_name = field['f']
    druid = field['b']&.split(':') || []
    text = field['d']
    accumulator << [fund_name, druid[1], file, text].join(' -|- ')
  end
end
to_field 'fund_facet' do |record, accumulator|
  Traject::MarcExtractor.new('979').collect_matching_lines(record) do |field, _spec, _extractor|
    file = field['c']
    next if file =~ /no content metadata/i

    druid = field['b']&.split(':') || []
    accumulator << field['f']
    accumulator << druid[1]
  end
end
#
# # Digitized Items Fields
to_field 'managed_purl_urls' do |record, accumulator|
  Traject::MarcExtractor.new('856u').collect_matching_lines(record) do |field, spec, extractor|
    accumulator.concat extractor.collect_subfields(field, spec) if field['x'] =~ /SDR-PURL/
  end
end

to_field 'collection_struct' do |record, accumulator|
  vern_fields = []

  Traject::MarcExtractor.cached('795ap', alternate_script: :only).each_matching_line(record) do |f|
    vern_fields << f
  end

  Traject::MarcExtractor.new('795ap',
                             alternate_script: false).collect_matching_lines(record) do |field, spec, extractor|
    struct = {
      title: extractor.collect_subfields(field, spec).join(' '),
      source: 'marc'
    }

    if field['6']
      link = parse_linkage(field)
      vern_field = vern_fields.find { |f| parse_linkage(f)[:number] == link[:number] }

      struct[:vernacular] = extractor.collect_subfields(vern_field, spec).join(' ') if vern_field.present?
    end

    accumulator << struct
  end

  vern_fields.select { |f| parse_linkage(f)[:number] == '00' }.each do |f|
    accumulator << {
      source: 'marc',
      vernacular: f.select { |sub| sub.code == 'a' || sub.code == 'p' }.map(&:value).join(' ')
    }
  end
end

to_field 'collection_struct' do |record, accumulator|
  Traject::MarcExtractor.new('856x').collect_matching_lines(record) do |field, spec, extractor|
    source, item_type, *other_data = extractor.collect_subfields(field, spec)
    next unless source == 'SDR-PURL' && item_type == 'item'

    data = other_data.select { |v| v =~ /:/ }.to_h { |v| v.split(':', 2) }

    next unless data['collection']

    druid, id, title = data['collection'].split(':')

    accumulator << {
      source:,
      item_type:,
      type: 'collection',
      druid:,
      id:,
      title:
    }
  end

  accumulator.uniq!
end

to_field 'marc_collection_title_ssim', extract_marc('795ap', alternate_script: false)
to_field 'vern_marc_collection_title_ssim', extract_marc('795ap', alternate_script: :only)

to_field 'collection', literal('sirsi')
# add folio to the collection list; searchworks has some dependencies on this value,
# so for now, we're just appending 'folio' to the list.
to_field 'collection', literal('folio')

to_field 'collection' do |record, accumulator|
  Traject::MarcExtractor.new('856x').collect_matching_lines(record) do |field, spec, extractor|
    subfields = extractor.collect_subfields(field, spec)
    next unless subfields[0] == 'SDR-PURL' && subfields[1] == 'item'

    accumulator.concat(subfields.slice(2..-1).map do |v|
      v.split(':')
    end.select do |(type, _druid, _id, _title)|
      type == 'collection'
    end.map do |(_type, druid, id, _title)|
      id.empty? ? druid : id.sub(/^a(\d+)$/, '\1')
    end)
  end
end

to_field 'collection_with_title' do |record, accumulator|
  Traject::MarcExtractor.new('856x').collect_matching_lines(record) do |field, spec, extractor|
    subfields = extractor.collect_subfields(field, spec)
    next unless subfields[0] == 'SDR-PURL' && subfields[1] == 'item'

    accumulator.concat(subfields.slice(2..-1).map do |v|
      v.split(':')
    end.select do |(type, _druid, _id, _title)|
      type == 'collection'
    end.map do |(_type, druid, id, title)|
      "#{id.empty? ? druid : id}-|-#{title}"
    end)
  end
end

to_field 'set' do |record, accumulator|
  Traject::MarcExtractor.new('856x').collect_matching_lines(record) do |field, spec, extractor|
    subfields = extractor.collect_subfields(field, spec)
    next unless subfields[0] == 'SDR-PURL' && subfields[1] == 'item'

    accumulator.concat(subfields.slice(2..-1).map do |v|
      v.split(':')
    end.select do |(type, _druid, _id, _title)|
      type == 'set'
    end.map do |(_type, druid, id, _title)|
      id.empty? ? druid : id.sub(/^a(\d+)$/, '\1')
    end)
  end
end

to_field 'set_with_title' do |record, accumulator|
  Traject::MarcExtractor.new('856x').collect_matching_lines(record) do |field, spec, extractor|
    subfields = extractor.collect_subfields(field, spec)
    next unless subfields[0] == 'SDR-PURL' && subfields[1] == 'item'

    accumulator.concat(subfields.slice(2..-1).map do |v|
      v.split(':')
    end.select do |(type, _druid, _id, _title)|
      type == 'set'
    end.map do |(_type, druid, id, title)|
      "#{id.empty? ? druid : id}-|-#{title}"
    end)
  end
end

to_field 'collection_type' do |record, accumulator|
  Traject::MarcExtractor.new('856x').collect_matching_lines(record) do |field, spec, extractor|
    subfields = extractor.collect_subfields(field, spec)

    accumulator << 'Digital Collection' if subfields[0] == 'SDR-PURL' && subfields[1] == 'collection'
  end
end

to_field 'file_id' do |record, accumulator|
  Traject::MarcExtractor.new('856x').collect_matching_lines(record) do |field, spec, extractor|
    subfields = extractor.collect_subfields(field, spec)
    next unless subfields[0] == 'SDR-PURL' && subfields[1] == 'item'

    accumulator.concat(subfields.slice(2..-1).map do |v|
      v.split(':')
    end.select do |(type, _file_id)|
      type == 'file'
    end.map do |(_type, file_id)|
      file_id
    end)
  end
end

##
# IIIF Manifest field based on the presense of "file", "*.jp2" match in an
# 856 SDR-PURL entry
to_field 'iiif_manifest_url_ssim' do |record, accumulator|
  Traject::MarcExtractor.new('856x').collect_matching_lines(record) do |field, spec, extractor|
    subfields = extractor.collect_subfields(field, spec)
    next unless subfields[0] == 'SDR-PURL' && subfields[1] == 'item'

    accumulator.concat(subfields.slice(2..-1).map do |v|
      v.split(':')
    end.select do |(type, file_id)|
      type == 'file' && /.*\.jp2/.match(file_id)
    end.map do |(_type, file_id)|
      "https://purl.stanford.edu/#{file_id.slice(0, 11)}/iiif/manifest"
    end)
  end
end

to_field 'crez_instructor_search' do |record, _accumulator, context|
  context.output_hash['crez_instructor_search'] = record.courses.flat_map { |course| course[:instructors] }.compact.sort.uniq
end

to_field 'crez_course_name_search' do |record, _accumulator, context|
  context.output_hash['crez_course_name_search'] = record.courses.map { |course| course[:course_name] }.compact.sort.uniq
end

to_field 'crez_course_id_search' do |record, _accumulator, context|
  context.output_hash['crez_course_id_search'] = record.courses.map { |course| course[:course_id] }.compact.sort.uniq
end

# This allows SW to match the folio coursereserves data with the Solr record
to_field 'courses_folio_id_ssim' do |record, _accumulator, context|
  context.output_hash['courses_folio_id_ssim'] = record.courses.map { |course| course[:folio_course_id] }
end

each_record do |_record, context|
  context.output_hash.reject do |k, _v|
    k == 'mhld_display' || k == 'item_display_struct' || k =~ /^url_/ || k =~ /^marc/
  end.transform_values do |v|
    v.map! do |x|
      x.respond_to?(:strip) ? x.strip : x
    end

    v.uniq!
  end
end

to_field 'context_source_ssi', literal('folio')

to_field 'context_version_ssi' do |_record, accumulator|
  accumulator << Utils.version
end

to_field 'context_input_name_ssi' do |_record, accumulator, context|
  accumulator << context.input_name
end

to_field 'context_input_modified_dtsi' do |_record, accumulator, context|
  accumulator << File.mtime(context.input_name).utc.iso8601 if context.input_name && File.exist?(context.input_name)
end

# Index the list of field tags from the record
to_field 'context_marc_fields_ssim' do |record, accumulator|
  accumulator.concat(record.tags)
end

# Index the list of subfield codes for each field
to_field 'context_marc_fields_ssim' do |record, accumulator|
  accumulator.concat(record.select { |f| f.is_a?(MARC::DataField) }.map do |field|
    [field.tag, field.subfields.map(&:code)].flatten.join
  end)
end

# Index the list of subfield codes for each field
to_field 'context_marc_fields_ssim' do |record, accumulator|
  accumulator.concat(record.select { |f| f.is_a?(MARC::DataField) }.map do |field|
    field.subfields.map(&:code).map do |code|
      ['?', field.tag, code].flatten.join
    end
  end.flatten.uniq)
end

to_field 'bib_search' do |record, accumulator, context|
  # authors, titles, series, publisher
  keep_fields = %w[
    100 110 111 130 210 222 242 243 245 246 247 260 264 440 490 700 710 711 800 810 811
  ]

  result = []
  record.each do |field|
    next unless keep_fields.include?(field.tag)

    subfield_values = field.subfields
                           .reject { |sf| Constants::EXCLUDE_FIELDS.include?(sf.code) }
                           .collect(&:value)

    next unless subfield_values.length > 0

    result << subfield_values.join(' ')
  end

  result += Array(context.output_hash['topic_search'])
  result += Array(context.output_hash['format_main_ssim'])

  accumulator << result.join(' ') if result.any?
end

to_field 'vern_bib_search' do |record, accumulator, context|
  # authors, titles, series, publisher
  keep_fields = %w[
    100 110 111 130 210 222 242 243 245 246 247 260 264 440 490 700 710 711 800 810 811
  ]

  result = []
  record.each do |field|
    next unless field.tag == '880'
    next if field['6'].nil? ||
            !field['6'].include?('-') ||
            !keep_fields.include?(field['6'].split('-')[0])

    subfield_values = field.subfields
                           .reject { |sf| Constants::EXCLUDE_FIELDS.include?(sf.code) }
                           .collect(&:value)

    next unless subfield_values.length > 0

    result << subfield_values.join(' ')
  end

  result += Array(context.output_hash['vern_topic_search'])
  result += Array(context.output_hash['format_main_ssim'])

  accumulator << result.join(' ') if result.any?
end

## FOLIO specific fields

## QUESTIONS / ISSUES
# - change hashed_id to use uuid_ssi, since it's already a hash of some other fields?
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
  accumulator << record.as_json.except('source_record', 'holdings', 'items')
end

to_field 'holdings_json_struct' do |record, accumulator|
  accumulator << {
    holdings: record.holdings,
    items: record.items
  }
end

# This allows Searchworks to query the boundWith children.
to_field 'bound_with_parent_item_ids_ssim' do |record, accumulator|
  accumulator.concat record.index_items.select(&:bound_with?).filter_map(&:id)
end

each_record do |_record, context|
  context.output_hash.select { |k, _v| k =~ /_struct$/ }.each do |k, v|
    context.output_hash[k] = Array(v).map { |x| JSON.generate(x) }
  end
end

each_record do |_record, context|
  t0 = context.clipboard[:benchmark_start_time]
  t1 = Time.now

  logger.debug('folio_config.rb') { "Processed #{context.source_record_id} (#{(t1 - t0).round(3)}s)" }
end
