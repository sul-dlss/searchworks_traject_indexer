$LOAD_PATH << File.expand_path('../..', __dir__)

require 'traject'
require 'traject/macros/marc21_semantics'
require 'traject/readers/marc_combining_reader'
require 'sirsi_holding'
require 'mhld_field'
require 'utils'
require 'csv'
require 'i18n'

I18n.available_locales = [:en]

extend Traject::Macros::Marc21
extend Traject::Macros::Marc21Semantics

ALPHABET = [*'a'..'z'].join('')
A_X = ALPHABET.slice(0, 24)
MAX_CODE_POINT = 0x10FFFF.chr(Encoding::UTF_8)

settings do
  provide 'solr.url', ENV['SOLR_URL']
  provide 'solr.version', ENV['SOLR_VERSION']
  provide 'processing_thread_pool', ENV['NUM_THREADS']
  provide "reader_class_name", "Traject::MarcCombiningReader"
  provide 'reserves_file', ENV['RESERVES_FILE']
  provide 'allow_duplicate_values',  false
  provide 'skip_empty_item_display', ENV['SKIP_EMPTY_ITEM_DISPLAY'].to_i

  if defined?(JRUBY_VERSION)
    require 'traject/manticore_http_client'
    provide 'solr_json_writer.http_client', Traject::ManticoreHttpClient.new
  end
end

# Change the XMLNS to match how solrmarc handles this
class SolrMarcStyleFastXMLWriter < MARC::FastXMLWriter
  class << self
    def open_collection(use_ns)
      if use_ns
        %Q{<collection xmlns="http://www.loc.gov/MARC21/slim">}.dup
      else
        "<collection>".dup
      end
    end
  end
end

# Monkey-patch MarcExtractor in order to add logic to strip subfields before
# joining them, for parity with solrmarc.
class Traject::MarcExtractor
  def collect_subfields(field, spec)
      subfields = field.subfields.collect do |subfield|
        subfield.value if spec.includes_subfield_code?(subfield.code)
      end.compact

      return subfields if subfields.empty? # empty array, just return it.

      if options[:separator] && spec.joinable?
        subfields = [subfields.map(&:strip).join(options[:separator])]
      end

      return subfields
  end
end

def extract_marc_and_prefer_non_alternate_scripts(spec, options = {})
  lambda do |record, accumulator, context|
    extract_marc(spec, options.merge(alternate_script: false)).call(record, accumulator, context)
    extract_marc(spec, options.merge(alternate_script: :only)).call(record, accumulator, context) if accumulator.empty?
  end
end

reserves_lookup = {}
File.open(settings['reserves_file'], 'r').each do |line|
  csv_options = {
    col_sep: '|', headers: 'rez_desk|resctl_exp_date|resctl_status|ckey|barcode|home_loc|curr_loc|item_rez_status|loan_period|rez_expire_date|rez_stage|course_id|course_name|term|instructor_name',
    header_converters: :symbol, quote_char: "\x00"
  }
  CSV.parse(line, csv_options) do |row|
    if row[:item_rez_status] == 'ON_RESERVE'
      ckey = row[:ckey]
      crez_value = reserves_lookup[ckey] || []
      reserves_lookup[ckey] = crez_value << row
    end
  end
end if settings['reserves_file']

each_record do |record|
  puts record if ENV['q']
end

to_field 'id', extract_marc('001') do |_record, accumulator|
  accumulator.map! do |v|
    v.sub(/^a/, '')
  end
end

to_field 'marcxml' do |record, accumulator|
  accumulator << (SolrMarcStyleFastXMLWriter.single_record_document(record, include_namespace: true) + "\n")
end

to_field 'marcbib_xml' do |record, accumulator|
  skip_fields = %w[852 853 854 855 863 864 865 866 867 868 999]
  filtered_fields = MARC::FieldMap.new
  record.each do |field|
    next if skip_fields.include?(field.tag)
    filtered_fields.push(field)
  end
  new_record = MARC::Record.new
  new_record.leader = record.leader
  filtered_fields.map { |f| new_record.append(f) }
  accumulator << (SolrMarcStyleFastXMLWriter.single_record_document(new_record, include_namespace: true) + "\n")
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
to_field 'vern_title_uniform_search', extract_marc('130adfgklmnoprst:240adfgklmnoprs', first: true, alternate_script: :only)
to_field 'title_variant_search', extract_marc('210ab:222ab:242abnp:243adfgklmnoprs:246abfgnp:247abfgnp', alternate_script: false)
to_field 'vern_title_variant_search', extract_marc('210ab:222ab:242abnp:243adfgklmnoprs:246abfgnp:247abfgnp', alternate_script: :only)
to_field 'title_related_search', extract_marc('505t:700fgklmnoprst:710dfgklmnoprst:711fgklnpst:730adfgklmnoprst:740anp:760st:762st:765st:767st:770st:772st:773st:774st:775st:776st:777st:780st:785st:786st:787st:796fgklmnoprst:797dfgklmnoprst:798fgklnpst:799adfgklmnoprst', alternate_script: false)
to_field 'vern_title_related_search', extract_marc('505tt:700fgklmnoprst:710dfgklmnoprst:711fgklnpst:730adfgklmnoprst:740anp:760st:762st:765st:767st:770st:772st:773st:774st:775st:776st:777st:780st:785st:786st:787st:796fgklmnoprst:797dfgklmnoprst:798fgklnpst:799adfgklmnoprst', alternate_script: :only)
# Title Display Fields
to_field 'title_245a_display', extract_marc('245a', first: true, alternate_script: false) do |record, accumulator|
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'vern_title_245a_display', extract_marc('245aa', first: true, alternate_script: :only) do |record, accumulator|
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'title_245c_display', extract_marc('245c', first: true, alternate_script: false) do |record, accumulator|
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'vern_title_245c_display', extract_marc('245cc', first: true, alternate_script: :only) do |record, accumulator|
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'title_display', extract_marc('245abdefghijklmnopqrstuvwxyz', first: true, alternate_script: false) do |record, accumulator|
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'vern_title_display', extract_marc('245abdefghijklmnopqrstuvwxyz', first: true, alternate_script: :only) do |record, accumulator|
  accumulator.map!(&method(:trim_punctuation_custom))
end
to_field 'title_full_display', extract_marc("245#{ALPHABET}", first: true, alternate_script: false)
to_field 'vern_title_full_display', extract_marc("245#{ALPHABET}", first: true, alternate_script: :only)
to_field 'title_uniform_display', extract_marc(%w(130 240).map { |c| "#{c}#{ALPHABET}" }.join(':'), first: true, alternate_script: false)
# # ? no longer will use title_uniform_display due to author-title searching needs ? 2010-11
# TODO: Remove looks like SearchWorks is not using, confirm relevancy changes
to_field 'vern_title_uniform_display', extract_marc(%w(130 240).map { |c| "#{c}#{ALPHABET}" }.join(':'), first: true, alternate_script: :only)
# # Title Sort Field
to_field 'title_sort' do |record, accumulator|
  result = []
  result << extract_sortable_title("130#{ALPHABET}", record)
  result << extract_sortable_title('245abdefghijklmnopqrstuvwxyz', record)
  str = result.join(' ').strip
  accumulator << str unless str.empty?
end

##
# Originally cribbed from Traject::Marc21Semantics.marc_sortable_title, but by
# using algorithm from StanfordIndexer#getSortTitle.
def extract_sortable_title(fields, record)
  java7_punct = '!"#$%&\'()*+,-./:;<=>?@[\]^_`{|}~\\'
  Traject::MarcExtractor.new(fields, separator: false, alternate_script: false).collect_matching_lines(record) do |field, spec, extractor|
    subfields = extractor.collect_subfields(field, spec).compact

    if subfields.empty? && field['k']
      # maybe an APPM archival record with only a 'k'
      subfields = [field['k']]
    end
    if subfields.empty?
      # still? All we can do is bail, I guess
      return nil
    end

    non_filing = field.indicator2.to_i
    subfields[0] = subfields[0].slice(non_filing..-1) if non_filing < subfields[0].length - 1
    subfields.map { |x| x.delete(java7_punct) }.map(&:strip).join(' ')
  end.first
end

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
  twoxx ||= Traject::MarcExtractor.cached('245a', alternate_script: false).extract(record).first if record['245']
  twoxx ||= 'null'

  accumulator << [onexx, twoxx].compact.reject(&:empty?).map(&:strip).join(' ') if onexx
end

to_field 'author_title_search' do |record, accumulator|
  onexx = Traject::MarcExtractor.cached('100abcdfghijklmnopqrstuvwxyz:110abcdfghijklmnopqrstuvwxyz:111abcdefghjklmnopqrstuvwxyz', alternate_script: :only).extract(record).first

  twoxx = Traject::MarcExtractor.cached('240' + ALPHABET, alternate_script: :only).extract(record).first
  twoxx ||= Traject::MarcExtractor.cached('245a', alternate_script: :only).extract(record).first
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
  accumulator << extract_sortable_author("100#{ALPHABET}:110#{ALPHABET}:111#{ALPHABET}",
                                         "240#{ALPHABET}:245#{ALPHABET.delete('c')}",
                                         record)
end

# Custom method cribbed from Traject::Macros::Marc21Semantics.marc_sortable_author
# https://github.com/traject/traject/blob/0914a396306c2489a7e270f33793ca76665f8f19/lib/traject/macros/marc21_semantics.rb#L51-L88
# Port from Solrmarc:MarcUtils#getSortableAuthor wasn't accurate
# This method differs in that:
#  245 field returned independent of 240 being present
#  punctuation actually gets stripped
#  only alpha subfields used
#  ensures record with no 1xx sorts after records with a 1xx by prepending UTF-8 max code point to title string
def extract_sortable_author(author_fields, title_fields, record)
  punct = '!"#$%&\'()*+,-./:;<=>?@[\]^_`{|}~\\'
  onexx = Traject::MarcExtractor.cached(author_fields, alternate_script: false, separator: false).collect_matching_lines(record) do |field, spec, extractor|
    non_filing = field.indicator2.to_i
    subfields = extractor.collect_subfields(field, spec).compact
    next if subfields.empty?
    subfields[0] = subfields[0].slice(non_filing..-1) if non_filing < subfields[0].length - 1
    subfields.map { |x| x.delete(punct) }.map(&:strip).join(' ')
  end.first

  onexx ||= MAX_CODE_POINT

  titles = []
  title_fields.split(':').each do |title_spec|
    titles << Traject::MarcExtractor.cached(title_spec, alternate_script: false, separator: false).collect_matching_lines(record) do |field, spec, extractor|
      non_filing = field.indicator2.to_i
      subfields = extractor.collect_subfields(field, spec).compact
      next if subfields.empty?
      subfields[0] = subfields[0].slice(non_filing..-1) if non_filing < subfields[0].length - 1
      subfields.map { |x| x.delete(punct) }.map(&:strip).join(' ')
    end.first
  end

  title = titles.compact.join(' ')
  title = title.delete(punct).strip if title

  return [onexx, title].compact.reject(&:empty?).join(' ')
end
#
# # Subject Search Fields
# #  should these be split into more separate fields?  Could change relevancy if match is in field with fewer terms
to_field "topic_search", extract_marc("650abcdefghijklmnopqrstuw:653abcdefghijklmnopqrstuw:654abcdefghijklmnopqrstuw:690abcdefghijklmnopqrstuw", alternate_script: false) do |record, accumulator|
  accumulator.reject! { |v| v == 'nomesh' }
  if record['999'] && record['999']['m'] == 'LANE-MED'
    arr = []
    extract_marc('655a').call(record, arr, nil)
    accumulator.reject! { |v| arr.include? v }
  end
end

to_field "vern_topic_search", extract_marc("650abcdefghijklmnopqrstuw:653abcdefghijklmnopqrstuw:654abcdefghijklmnopqrstuw:690abcdefghijklmnopqrstuw", alternate_script: :only)
to_field "topic_subx_search", extract_marc("600x:610x:611x:630x:650x:651x:655x:656x:657x:690x:691x:696x:697x:698x:699x", alternate_script: false)
to_field "vern_topic_subx_search", extract_marc("600xx:610xx:611xx:630xx:650xx:651xx:655xx:656xx:657xx:690xx:691xx:696xx:697xx:698xx:699xx", alternate_script: :only)
to_field "geographic_search", extract_marc("651abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw", alternate_script: false)
to_field "vern_geographic_search", extract_marc("651abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw", alternate_script: :only)
to_field "geographic_subz_search", extract_marc("600z:610z:630z:650z:651z:654z:655z:656z:657z:690z:691z:696z:697z:698z:699z", alternate_script: false)

to_field "vern_geographic_subz_search", extract_marc("600zz:610zz:630zz:650zz:651zz:654zz:655zz:656zz:657zz:690zz:691zz:696zz:697zz:698zz:699zz", alternate_script: :only)
to_field "subject_other_search", extract_marc(%w(600 610 611 630 655 656 657 658 696 697 698 699).map { |c| "#{c}abcdefghijklmnopqrstuw"}.join(':'), alternate_script: false) do |record, accumulator|
  accumulator.reject! { |v| v == 'nomesh' }
  if record['999'] && record['999']['m'] == 'LANE-MED'
    arr = []
    extract_marc('655a').call(record, arr, nil)
    accumulator.reject! { |v| arr.include? v }
  end
end
to_field "vern_subject_other_search", extract_marc(%w(600 610 611 630 655 656 657 658 696 697 698 699).map { |c| "#{c}abcdefghijklmnopqrstuw"}.join(':'), alternate_script: :only)
to_field "subject_other_subvy_search", extract_marc(%w(600 610 611 630 650 651 654 655 656 657 658 690 691 696 697 698 699).map { |c| "#{c}vy"}.join(':'), alternate_script: false)
to_field "vern_subject_other_subvy_search", extract_marc(%w(600 610 611 630 650 651 654 655 656 657 658 690 691 696 697 698 699).map { |c| "#{c}vy"}.join(':'), alternate_script: :only)
to_field "subject_all_search", extract_marc(%w(600 610 611 630 648 650 651 652 653 654 655 656 657 658 662 690 691 696 697 698 699).map { |c| "#{c}#{ALPHABET}" }.join(':'), alternate_script: false)
to_field "vern_subject_all_search", extract_marc(%w(600 610 611 630 648 650 651 652 653 654 655 656 657 658 662 690 691 696 697 698 699).map { |c| "#{c}#{ALPHABET}"}.join(':'), alternate_script: :only)

# Subject Facet Fields
to_field "topic_facet", extract_marc("600abcdq:600t:610ab:610t:630a:630t:650a", alternate_script: false) do |record, accumulator|
  accumulator.map! { |v| trim_punctuation_custom(v, /([\p{L}\p{N}]{4}|[A-Za-z]{3}|[\)])\. *\Z/) }
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.reject! { |v| v == 'nomesh' }
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

def clean_facet_punctuation(value)
  new_value = value.gsub(/^[%\*]/, ''). # begins with percent sign or asterisk
                    gsub(/\({2,}+/, '('). # two or more open parentheses
                    gsub(/\){2,}+/, ')'). # two or more close parentheses
                    gsub(/!{2,}+/, '!'). #  two or more exlamation points
                    gsub(/\s+/, ' ') # one or more spaces

  StringScrubbing.balance_parentheses(new_value)
end

# Custom method for traject's trim_punctuation
# https://github.com/traject/traject/blob/5754e3c0c207d461ca3a98728f7e1e7cf4ebbece/lib/traject/macros/marc21.rb#L227-L246
# Does the same except removes trailing period when preceded by at
# least four letters instead of three.
def trim_punctuation_custom(str, trailing_period_regex = nil)
  return str unless str
  trailing_period_regex ||= /( *[A-Za-z]{4,}|[0-9]{3}|\)|,)\. *\Z/

  previous_str = nil
  until str == previous_str
    previous_str = str
    # If something went wrong and we got a nil, just return it
    # trailing: comma, slash, semicolon, colon (possibly preceded and followed by whitespace)
    str = str.sub(/ *[ \\,\/;:] *\Z/, '')

    # trailing period if it is preceded by at least four letters (possibly preceded and followed by whitespace)
    str = str.gsub(trailing_period_regex, '\1')

    # trim any leading or trailing whitespace
    str.strip!
  end

  return str
end

def trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff(str)
  previous_str = nil
  until str == previous_str
    previous_str = str

    str = str.strip.gsub(/ *([,\/;:])$/, '')
                   .sub(/(\w\w)\.$/, '\1')
                   .sub(/(\p{L}\p{L})\.$/, '\1')
                   .sub(/(\w\p{InCombiningDiacriticalMarks}?\w\p{InCombiningDiacriticalMarks}?)\.$/, '\1')


    # single square bracket characters if they are the start and/or end
    #   chars and there are no internal square brackets.
    str = str.sub(/\A\[?([^\[\]]+)\]?\Z/, '\1')
    str = str.sub(/\A\[/, '') if str.index(']').nil? # no closing bracket
    str = str.sub(/\]\Z/, '') if str.index('[').nil? # no opening bracket

    str
  end

  str
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

# # publication dates
def clean_date_string(value)
  value = value.strip
  valid_year_regex = /(?:20|19|18|17|16|15|14|13|12|11|10|09|08|07|06|05)[0-9][0-9]/

  # some nice regular expressions looking for years embedded in strings
  matches = [
    /^(#{valid_year_regex})\D{0,2}$/,
    /\[(#{valid_year_regex})\]/,
    /^\[?[©Ⓟcp](#{valid_year_regex})\D?$/,
    /i\. ?e\. ?(#{valid_year_regex})\D?/,
    /\[(#{valid_year_regex})\D.*\]/,
  ].map { |r| r.match(value)&.captures&.first }

  best_match = matches.compact.first if matches

  # reject BC dates altogether.
  return if value =~ /[0-9]+ B\.?C\.?/i

  # else if (bracesAround19Matcher.find())
  #   cleanDate = bracesAround19Matcher.group().replaceAll("\\[", "").replaceAll("\\]", "");
  # else if (unclearLastDigitMatcher.find())
  #   cleanDate = unclearLastDigitMatcher.group().replaceAll("[-?]", "0");

  # if a year starts with an l instead of a 1
  best_match ||= if value =~ /l((?:9|8|7|6|5)\d{2,2})\D?/
    "1#{$1}"
  end
  # brackets around the century, e.g. [19]56
  best_match ||= if value =~ /\[19\](\d\d)\D?/
    "19#{$1}"
  end
  # uncertain last digit
  best_match ||= if value =~ /((?:20|19|18|17|16|15)[0-9])[-?]/
    "#{$1}0"
  end

  # is the date no more than 1 year in the future?
  best_match.to_i.to_s if best_match.to_i >= 500 && best_match.to_i <= Time.now.year + 1
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
    "#{record['008'].value[7..8]}--"
  end

  # colons sort after 9, so the lexical sorting will be correct. I think.
  # NOTE: the solrmarc code has this comment, and yet still uses hyphens below; maybe a bug?
  year ||= if f008_bytes11to14 =~ /\d\d[u-][u-]/
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

def marc_008_date(byte6values, byte_range, u_replacement)
  lambda do |record, accumulator|
    Traject::MarcExtractor.new('008').collect_matching_lines(record) do |field, spec, extractor|
      if byte6values.include? field.value[6]
        year = field.value[byte_range]
        next unless year =~ /(\d{4}|\d{3}[u-])/
        year.gsub!(/[u-]$/, u_replacement)
        next unless (500..(Time.now.year + 10)).include? year.to_i
        accumulator << year.to_i.to_s
      end
    end
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

# returns the a value comprised of 250ab and 260a-g, suitable for display
to_field 'imprint_display' do |record, accumulator|
  edition = Traject::MarcExtractor.new('250ab', alternate_script: false).extract(record).uniq.map(&:strip).join(' ')
  vernEdition = Traject::MarcExtractor.new('250ab', alternate_script: :only).extract(record).uniq.map(&:strip).join(' ')

  imprint = Traject::MarcExtractor.new('260abcefg', alternate_script: false).extract(record).uniq.map(&:strip).join(' ')
  vernImprint = Traject::MarcExtractor.new('260abcefg', alternate_script: :only).extract(record).uniq.map(&:strip).join(' ')

  data = [
    [edition, vernEdition].compact.reject(&:empty?).join(' '),
    [imprint, vernImprint].compact.reject(&:empty?).join(' ')
  ].compact.reject(&:empty?)

  accumulator << data.join(' - ') if data.any?
end
#
# # Date field for new items feed
to_field "date_cataloged", extract_marc("916b") do |record, accumulator|
  accumulator.reject! { |v| v =~ /NEVER/i }

  accumulator.map! do |v|
    "#{v[0..3]}-#{v[4..5]}-#{v[6..7]}T00:00:00Z"
  end
end

#
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

#
# # URL Fields
# get full text urls from 856, then reject gsb forms
to_field 'url_fulltext' do |record, accumulator|
  Traject::MarcExtractor.new('856u', alternate_script: false).collect_matching_lines(record) do |field, spec, extractor|
    case field.indicator2
    when '0'
      accumulator.concat extractor.collect_subfields(field, spec)
    when '2'
      # no-op
    else
      accumulator.concat extractor.collect_subfields(field, spec) unless field.subfields.select { |f| f.code == 'z' || f.code == '3' }.map(&:value).any? { |v| v =~ /(table of contents|abstract|description|sample text)/i}
    end
  end

  accumulator.reject! do |v|
    v.start_with?('http://www.gsb.stanford.edu/jacksonlibrary/services/') ||
    v.start_with?('https://www.gsb.stanford.edu/jacksonlibrary/services/')
  end
end

# get all 956 subfield u containing fulltext urls that aren't SFX
to_field 'url_fulltext', extract_marc('956u') do |record, accumulator|
  accumulator.reject! do |v|
    v.start_with?('http://caslon.stanford.edu:3210/sfxlcl3?') ||
    v.start_with?('http://library.stanford.edu/sfx?')
  end
end

# returns the URLs for supplementary information (rather than fulltext)
to_field 'url_suppl' do |record, accumulator|
  Traject::MarcExtractor.new('856u').collect_matching_lines(record) do |field, spec, extractor|
    case field.indicator2
    when '0'
      # no-op
    when '2'
      accumulator.concat extractor.collect_subfields(field, spec)
    else
      accumulator.concat extractor.collect_subfields(field, spec) if field.subfields.select { |f| f.code == 'z' || f.code == '3' }.map(&:value).any? { |v| v =~ /(table of contents|abstract|description|sample text)/i}
    end
  end
end

to_field 'url_sfx', extract_marc('956u') do |record, accumulator|
  accumulator.select! { |v| v =~ Regexp.union(%r{^http://library.stanford.edu/sfx\?.+}, %r{^http://caslon.stanford.edu:3210/sfxlcl3\?.+}) }
end

# returns the URLs for restricted full text of a resource described
#  by the 856u.  Restricted is determined by matching a string against
#  the 856z.  ("available to stanford-affiliated users at:")
to_field 'url_restricted' do |record, accumulator|
  Traject::MarcExtractor.new('856u').collect_matching_lines(record)  do |field, spec, extractor|
    next unless field.subfields.select { |f| f.code == 'z' }.map(&:value).any? { |z| z =~ /available to stanford-affiliated users at:/i }
    case field.indicator2
    when '0'
      accumulator.concat extractor.collect_subfields(field, spec)
    when '2'
      # no-op
    else
      accumulator.concat extractor.collect_subfields(field, spec) unless (field.subfields.select { |f| f.code == 'z' }.map(&:value) + [field['3']]).any? { |v| v =~ /(table of contents|abstract|description|sample text)/i}
    end
  end
end

#
to_field 'access_facet' do |record, accumulator, context|
  online_locs = ['E-RECVD', 'E-RESV', 'ELECTR-LOC', 'INTERNET', 'KIOST', 'ONLINE-TXT', 'RESV-URL', 'WORKSTATN']
  Traject::MarcExtractor.new('999').collect_matching_lines(record) do |field, spec, extractor|
    holding = SirsiHolding.new(
      call_number: (field['a'] || '').strip,
      current_location: field['k'],
      home_location: field['l'],
      library: field['m'],
      scheme: field['w'],
      type: field['t']
    )

    next if holding.skipped?

    if online_locs.include?(field['k']) || online_locs.include?(field['l']) || holding.e_call_number?
      accumulator << 'Online'
    elsif field['a'] =~ /^XX/ && (field['k'] == 'ON-ORDER' || (!field['k'].nil? && !field['k'].empty? && field['l'] != 'INPROCESS' && field['k'] != 'INPROCESS' && field['k'] != 'LAC' && field['l'] != 'LAC' && field['m'] != 'HV-ARCHIVE'))
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
  accumulator << 'Other' if context.output_hash['format_main_ssim'].nil? || context.output_hash['format_main_ssim'].empty?
end

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

to_field 'format_physical_ssim', extract_marc('300a', alternate_script: false) do |record, accumulator|
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

to_field 'genre_ssim', extract_marc('655av', alternate_script: false)do |record, accumulator|
  # normalize values
  accumulator.map! do |v|
    previous_v = nil
    until v == previous_v
      previous_v = v
      v = v.strip.sub(/([\\,;:])+$/, '').sub(/([\p{L}\p{N}]{4}|\.*?[\s)]|[..{2,}]|[AMUaw][adir][cirt])\.$/, '\1').strip
    end
    v
  end

  accumulator.map!(&method(:clean_facet_punctuation))
end

to_field 'genre_ssim', extract_marc('600v:610v:611v:630v:647v:648v:650v:651v:654v:656v:657v', alternate_script: false) do |record, accumulator|
  # normalize values
  accumulator.map! do |v|
    previous_v = nil
    until v == previous_v
      previous_v = v
      v = v.strip.sub(/([\\,;:])+$/, '').sub(/([\p{L}\p{N}]{4}|\.*?[\s)]|[..{2,}]|[AMUaw][adir][cirt])\.$/, '\1').strip
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
  if record.leader[7] == 'm' || record.leader[7] == 's'
    accumulator << 'Conference proceedings' if record['008'] && record['008'].value[29] == '1'
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

  if record['008'] && record['008'].value[28] && record['008'].value[28] =~ /[a-z]/
    accumulator << 'Government document'
  end
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
    accumulator << 'Technical report' if (record.leader[6] == 'a' || record.leader[6] == 't') && record['008'].value[24..27] =~ /t/
  elsif record['027'] || record['088']
    accumulator << 'Technical report'
  elsif record['006'] && (record['006'].value[0] == 'a' || record['006'].value[0] == 't') && record['006'].value[7..10] =~ /t/
    accumulator << 'Technical report'
  end
end

to_field 'db_az_subject', extract_marc('099a') do |record, accumulator, context|
  if context.output_hash['format_main_ssim'].include? 'Database'
    translation_map = Traject::TranslationMap.new('db_subjects_map')
    accumulator.replace translation_map.translate_array(accumulator).flatten
  else
    accumulator.replace([])
  end
end

to_field 'db_az_subject' do |record, accumulator, context|
  if context.output_hash['format_main_ssim'].include? 'Database'
    if record['099'].nil?
      accumulator << 'Uncategorized'
    end
  end
end

to_field "physical", extract_marc("300abcefg", alternate_script: false)
to_field "vern_physical", extract_marc("300abcefg", alternate_script: :only)

to_field "toc_search", extract_marc("905art:505art", alternate_script: false)
to_field "vern_toc_search", extract_marc("505art", alternate_script: :only)
to_field "context_search", extract_marc("518a", alternate_script: false)
to_field "vern_context_search", extract_marc("518aa", alternate_script: :only)
to_field "summary_search", extract_marc("920ab:520ab", alternate_script: false)
to_field "vern_summary_search", extract_marc("520ab", alternate_script: :only)
to_field "award_search", extract_marc("986a:586a", alternate_script: false)

# # Standard Number Fields
to_field 'isbn_search', extract_marc('020a:020z:770z:771z:772z:773z:774z:775z:776z:777z:778z:779z:780z:781z:782z:783z:784z:785z:786z:787z:788z:789z', alternate_script: false) do |_record, accumulator|
  accumulator.map!(&method(:extract_isbn))
end

# # Added fields for searching based upon list from Kay Teel in JIRA ticket INDEX-142
to_field 'issn_search', extract_marc('022a:022l:022m:022y:022z:400x:410x:411x:440x:490x:510x:700x:710x:711x:730x:760x:762x:765x:767x:770x:771x:772x:773x:774x:775x:776x:777x:778x:779x:780x:781x:782x:783x:784x:785x:786x:787x:788x:789x:800x:810x:811x:830x', alternate_script: false) do |_record, accumulator|
  accumulator.map!(&:strip)
  accumulator.select! { |v| v =~ issn_pattern }
end

# INDEX-142 NOTE: Lane Medical adds (Print) or (Digital) descriptors to their ISSNs
# so need to account for it in the pattern match below
def issn_pattern
  /^\d{4}-\d{3}[X\d]\D*$/
end

def extract_isbn(value)
  value = value.strip
  isbn10_pattern = /^\d{9}[\dX].*/
  isbn13_pattern = /^(978|979)\d{9}[\dX].*/
  isbn13_any = /^\d{12}[\dX].*/

  if value =~ isbn13_pattern
    value[0, 13]
  elsif value =~ isbn10_pattern && value !~ isbn13_any
    value[0, 10]
  end
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

to_field 'lccn', extract_marc('010a', first: true) do |record, accumulator|
  accumulator.map!(&:strip)
  lccn_pattern = /^(([ a-z]{3}\d{8})|([ a-z]{2}\d{10})) ?|( \/.*)?$/
  accumulator.select! { |x| x =~ lccn_pattern }

  accumulator.map! do |value|
    value.gsub(lccn_pattern, '\1')
  end
end

to_field 'lccn', extract_marc('010z', first: true) do |record, accumulator, context|
  accumulator.map!(&:strip)
  accumulator.replace([]) and next unless context.output_hash['lccn'].nil?
  lccn_pattern = /^(([ a-z]{3}\d{8})|([ a-z]{2}\d{10})) ?|( \/.*)?$/
  accumulator.select! { |x| x =~ lccn_pattern }

  accumulator.map! do |value|
    value.gsub(lccn_pattern, '\1')
  end
end

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
    next unless data[/\A(?:ocm)|(?:ocn)|(?:on)/]
    data.sub(/\A(?:ocm)|(?:ocn)|(?:on)/, '')
  end.flatten.compact.uniq

  if marc035_with_m_suffix.any?
    accumulator.concat marc035_with_m_suffix
  elsif marc079.any?
    accumulator.concat marc079
  elsif marc035_without_m_suffix.any?
    accumulator.concat marc035_without_m_suffix
  end
end
#
# # Call Number Fields
to_field 'callnum_facet_hsim' do |record, accumulator|
  record.each_by_tag('999') do |item|
    holding = SirsiHolding.new(
      call_number: (item['a'] || '').strip,
      current_location: item['k'],
      home_location: item['l'],
      library: item['m'],
      scheme: item['w'],
      type: item['t']
    )

    next if holding.skipped?
    next unless holding.call_number_type == 'LC'
    next if holding.call_number.to_s.empty? ||
            holding.bad_lc_lane_call_number? ||
            holding.shelved_by_location? ||
            holding.lost_or_missing? ||
            holding.ignored_call_number?

    translation_map = Traject::TranslationMap.new('call_number')
    cn = holding.call_number.normalized_lc
    next unless SirsiHolding::CallNumber.new(cn).valid_lc?

    first_letter = cn[0, 1].upcase
    letters = cn[/^[A-Z]+/]

    next unless first_letter && translation_map[first_letter]

    accumulator << [
      'LC Classification',
      translation_map[first_letter],
      translation_map[letters] || letters
    ].join('|')
  end
end

to_field 'callnum_facet_hsim' do |record, accumulator|
  marc_086 = record.fields('086')
  gov_doc_values = []
  record.each_by_tag('999') do |item|
    holding = SirsiHolding.new(
      call_number: (item['a'] || '').strip,
      current_location: item['k'],
      home_location: item['l'],
      library: item['m'],
      scheme: item['w']
    )

    next if holding.skipped?
    next unless holding.gov_doc_loc? ||
                marc_086.any? ||
                holding.call_number_type == 'SUDOC'

    translation_map = Traject::TranslationMap.new('gov_docs_locations', default: 'Other')
    raw_location = translation_map[holding.home_location]

    if raw_location == 'Other'
      if marc_086.any?
        marc_086.each do |marc_field|
          gov_doc_values << if false && marc_field['2'] == 'cadocs'
                              'California'
                            elsif false && marc_field['2'] == 'sudocs'
                              'Federal'
                            elsif false && marc_field['2'] == 'undocs'
                              'International'
                            elsif marc_field.indicator1 == '0'
                              'Federal'
                            else
                              raw_location
                            end
        end
      else
        gov_doc_values << raw_location
      end
    else
      gov_doc_values << raw_location
    end
  end

  gov_doc_values.uniq.each do |gov_doc_value|
    accumulator << ['Government Document', gov_doc_value].join('|')
  end
end

to_field 'callnum_facet_hsim' do |record, accumulator|
  record.each_by_tag('999') do |item|
    holding = SirsiHolding.new(
      call_number: (item['a'] || '').strip,
      current_location: item['k'],
      home_location: item['l'],
      library: item['m'],
      scheme: item['w']
    )

    next if holding.skipped?
    next unless holding.call_number_type == 'DEWEY' || (holding.call_number_type == 'LC' && holding.call_number.to_s =~ /^\d{1,3}(\.\d+)? *\.?[A-Z]\d{1,3} *[A-Z]*+.*/)
    next unless holding.dewey?
    next if holding.ignored_call_number? ||
            holding.shelved_by_location? ||
            holding.lost_or_missing?

    cn = holding.call_number.with_leading_zeros
    first_digit = "#{cn[0, 1]}00s"
    two_digits = "#{cn[0, 2]}0s"

    translation_map = Traject::TranslationMap.new('call_number')

    accumulator << [
      'Dewey Classification',
      translation_map[first_digit],
      translation_map[two_digits]
    ].join('|')
  end

  accumulator.uniq!
end

to_field 'callnum_search' do |record, accumulator|
  good_call_numbers = []
  record.each_by_tag('999') do |item|
    holding = SirsiHolding.new(
      call_number: (item['a'] || '').strip,
      current_location: item['k'],
      home_location: item['l'],
      library: item['m'],
      scheme: item['w']
    )

    next if holding.skipped?
    next if holding.call_number.to_s.empty? ||
            holding.shelved_by_location? ||
            holding.ignored_call_number? ||
            holding.bad_lc_lane_call_number?

    call_number = holding.call_number.to_s

    if holding.call_number_type == 'DEWEY' || holding.call_number_type == 'LC'
      call_number = call_number.strip
      call_number = call_number.gsub(/\s\s+/, ' ') # reduce multiple whitespace chars to a single space
      call_number = call_number.gsub(/\. \./, ' .') # reduce multiple whitespace chars to a single space
      call_number = call_number.gsub(/(\d+\.) ([A-Z])/, '\1\2') # remove space after a period if period is after digits and before letters
      call_number = call_number.gsub(/\s*\.$/, '') # remove trailing period and any spaces before it
    end

    good_call_numbers << call_number
  end

  accumulator.concat(good_call_numbers.uniq)
end

to_field 'callnum_facet_hsim', extract_marc('050ab') do |record, accumulator, context|
  accumulator.replace([]) and next if context.output_hash['callnum_facet_hsim']

  accumulator.map! do |cn|
    next unless cn =~ SirsiHolding::CallNumber::VALID_LC_REGEX

    first_letter = cn[0, 1].upcase
    letters = cn.split(/[^A-Z]+/).first

    translation_map = Traject::TranslationMap.new('call_number')

    next unless first_letter && translation_map[first_letter]

    [
      'LC Classification',
      translation_map[first_letter],
      translation_map[letters] || letters
    ].join('|')
  end

  accumulator.replace([accumulator.compact.first])
end

to_field 'callnum_facet_hsim', extract_marc('090ab') do |record, accumulator, context|
  accumulator.replace([]) and next if context.output_hash['callnum_facet_hsim']
  accumulator.map! do |cn|
    next unless cn =~ SirsiHolding::CallNumber::VALID_LC_REGEX

    first_letter = cn[0, 1].upcase
    letters = cn.split(/[^A-Z]+/).first

    translation_map = Traject::TranslationMap.new('call_number')

    next unless first_letter && translation_map[first_letter]

    [
      'LC Classification',
      translation_map[first_letter],
      translation_map[letters] || letters
    ].join('|')
  end

  accumulator.replace([accumulator.compact.first])
end

# shelfkey = custom, getShelfkeys

# given a shelfkey (a lexicaly sortable call number), return the reverse
# shelf key - a sortable version of the call number that will give the
# reverse order (for getting "previous" call numbers in a list)
#
# return the reverse String value, mapping A --> 9, B --> 8, ...
#   9 --> A and also non-alphanum to sort properly (before or after alphanum)
to_field 'reverse_shelfkey' do |record, accumulator, context|
  accumulator.concat(Array(context.output_hash['shelfkey']).map do |shelfkey|
    forward_chars = ('0'..'9').to_a + ('a'..'z').to_a
    reverse_chars = forward_chars.reverse
    char_map = forward_chars.zip(reverse_chars).to_h
    char_map.merge! '.' => '}', '{' => ' ', '|' => ' ', '}' => ' ', '~' => ' ', ' ' => '~'

    shelfkey.chars.map do |c|
      # map latin chars with diacritic to char without and normalize case
      c = I18n.transliterate(c).downcase

      if char_map[c]
        char_map[c]
      elsif c =~ /\w/
        # if it's not a character in our map, it's probably a non-latin, non-digit
        # which ordinarily sorts after 0-9, A-Z, so sort it first.
        '0'
      else
        # and if it is not a letter or a digit, sort it last
        '~'
      end
    end.join('').ljust(50, '~') # for some reason, we pad this to 50 characters.
  end)
end

#
# # Location facet
to_field 'location_facet', extract_marc('852c:999l') do |record, accumulator|
  location_values = accumulator.dup
  accumulator.replace([])

  if location_values.any? { |x| x == 'CURRICULUM' }
    accumulator << 'Curriculum Collection'
  end

  if location_values.any? { |x| x =~ /^ARTLCK/ or x == 'PAGE-AR'}
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
      when /(.*)\s?.?a\.\s?m\.\s?(.*)/, /(.*)m\.\s?a[\.\)]\s?(.*)/, /(.*)m\.\s?a\.?\s?(.*)/
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
    Traject::MarcExtractor.cached('710ab').collect_matching_lines(record) do |field, spec, extractor|
      sub_a ||= field['a']
      sub_b ||= field['b']
      if sub_a =~ /stanford/i
        if !sub_b.nil? # subfield b exists
          sub_b = sub_b.strip # could contain just whitespace
          if sub_b.empty?
            accumulator << sub_a
          else
            accumulator << sub_b
          end
        else # subfield b does not exist, subfield a is Stanford
          accumulator << sub_a
        end
      end
    end
  end

  accumulator.map!(&method(:trim_punctuation_custom))
  accumulator.map!(&method(:clean_facet_punctuation))
  accumulator.replace(accumulator.map do |value|
    value = value.gsub(/Dept\./, 'Department')
    value = value.gsub(/([\p{L}\p{N}]{4}|\.*?[\s)]|[..{2,}]|[LAE][arn][wtg])\.$/, '\1')
  end)
end
#
# # Item Info Fields (from 999 that aren't call number)
to_field 'barcode_search', extract_marc('999i')
# preferred_barcode = custom, getPreferredItemBarcode
# access_facet = custom, getAccessMethods

library_map = Traject::TranslationMap.new('library_map')
resv_locs = Traject::TranslationMap.new('locations_reserves_list')

to_field 'building_facet' do |record, accumulator|
  record.each_by_tag('999') do |item|
    holding = SirsiHolding.new(
      call_number: (item['a'] || '').strip,
      current_location: item['k'],
      home_location: item['l'],
      library: item['m'],
      scheme: item['w'],
      type: item['t']
    )

    next if holding.skipped?

    curr_loc = item['k']
    home_loc = item['l']
    library = item['m']

    if resv_locs.hash.key?(curr_loc)
      accumulator << curr_loc
    else
      accumulator << library
      # https://github.com/sul-dlss/solrmarc-sw/issues/101
      # Per Peter Blank - items with library = SAL3 and home location = PAGE-AR
      # should be given two library facet values:
      # SAL3 (off-campus storage) <- they are currently getting this
      # and Art & Architecture (Bowes) <- new requirement
      if (library == 'SAL3') && (home_loc == 'PAGE-AR')
        accumulator << 'ART'
      end
    end
  end
  accumulator.replace library_map.translate_array(accumulator)
end

to_field 'building_facet' do |record, accumulator|
  Traject::MarcExtractor.new('856u').collect_matching_lines(record) do |field, spec, extractor|
    accumulator << 'Stanford Digital Repository' if field['x'] =~ /SDR-PURL/ || field['u'] =~ /purl\.stanford\.edu/
  end
end


to_field 'building_facet', extract_marc('596a', translation_map: 'library_on_order_map') do |record, accumulator|
  accumulator.replace([]) if record['999']

  accumulator.replace library_map.translate_array(accumulator)
end

to_field 'item_display' do |record, accumulator|
  record.each_by_tag('999') do |item_999|
    holding = SirsiHolding.new(
      call_number: (item_999['a'] || '').strip,
      current_location: item_999['k'],
      home_location: item_999['l'],
      library: item_999['m'],
      scheme: item_999['w'],
      type: item_999['t']
    )

    next if holding.skipped?

    accumulator << [
      item_999['i'],
      holding.library,
      holding.home_location,
      holding.current_location,
      holding.type,
      '', # itemDispCallnum/loppedCallnum
      '', # shelfkey
      '', # reverse shelfkey
      (holding.call_number unless holding.ignored_call_number?),
      '', # volSort
      (item_999['o'] if item_999['o'] && item_999['o'].upcase.start_with?('.PUBLIC.')),
      holding.call_number_type
    ].join(' -|- ')
  end
end

##
# Skip records for missing `item_display` field
each_record do |record, context|
  context.skip!('No item_display field') if context.output_hash['item_display'].nil? && settings['skip_empty_item_display'] > -1
end

to_field 'on_order_library_ssim', extract_marc('596a', translation_map: 'library_on_order_map')
##
# Instantiate once, not on each record
skipped_locations = Traject::TranslationMap.new('locations_skipped_list')
missing_locations = Traject::TranslationMap.new('locations_missing_list')

to_field 'mhld_display' do |record, accumulator, context|
  mhld_field = MhldField.new
  mhld_results = []

  Traject::MarcExtractor.new('852:853:863:866:867:868').collect_matching_lines(record) do |field, spec, extractor|
    case field.tag
    when '852'
      # Adds the previous 852 with setup things from other fields (853, 863, 866, 867, 868)
      mhld_results.concat add_values_to_result(mhld_field)

      # Reset to process new 852
      mhld_field = MhldField.new

      used_sub_fields = field.subfields.select do |sf|
        %w[3 z b c].include? sf.code
      end
      comment = []
      comment << used_sub_fields.map { |sf| sf.value if sf.code == '3' }.compact.join(' ')
      comment << used_sub_fields.map { |sf| sf.value if sf.code == 'z' }.compact.join(' ')
      comment = comment.reject(&:empty?).join(' ')
      next if comment =~ /all holdings transferred/i

      library_code = used_sub_fields.collect { |sf| sf.value if sf.code == 'b' }.compact.join(' ')
      library_code = 'null' if library_code.empty?
      location_code = used_sub_fields.collect { |sf| sf.value if sf.code == 'c' }.compact.join(' ')
      location_code = 'null' if location_code.empty?

      next if skipped_locations[location_code] || missing_locations[location_code]

      mhld_field.library = library_code
      mhld_field.location = location_code
      mhld_field.public_note = comment

      ##
      # Check if a subfield = exists
      mhld_field.df852has_equals_sf = field.subfields.select do |sf|
        ['='].include? sf.code
      end.compact.any?
    when '853'
      link_seq_num = field.subfields.select do |sf|
        %w[8].include? sf.code
      end.collect(&:value).first.to_i

      mhld_field.patterns853[link_seq_num] = field
    when '863'
      sub8 = field.subfields.select do |sf|
        %w[8].include? sf.code
      end.collect(&:value).first.to_s.strip
      next if sub8.empty?
      link_num, seq_num = sub8.split('.').map(&:to_i)

      if mhld_field.most_recent863link_num < link_num || (
        mhld_field.most_recent863link_num == link_num && mhld_field.most_recent863seq_num < seq_num
      )
        mhld_field.most_recent863link_num = link_num
        mhld_field.most_recent863seq_num = seq_num
        mhld_field.most_recent863 = field
      end
    when '866'
      mhld_field.fields866 << field
    when '867'
      mhld_field.fields867 << field
    when '868'
      mhld_field.fields868 << field
    end
  end
  accumulator.concat mhld_results.concat add_values_to_result(mhld_field)
end

def add_values_to_result(mhld_field)
  return [] if mhld_field.library.nil?
  latest_recd_out = false
  has866 = false
  has867 = false
  has868 = false
  mhld_results = []
  mhld_field.fields866.each do |f|
    sub_a = f['a'] || ''

    mhld_field.library_has = library_has(f)
    if sub_a.end_with?('-')
      unless latest_recd_out
        latest_received = mhld_field.latest_received
        latest_recd_out = true
      end
    end
    has866 = true
    mhld_results << mhld_field.display(latest_received)
  end
  mhld_field.fields867.each do |f|
    mhld_field.library_has = "Supplement: #{library_has(f)}"
    latest_received = mhld_field.latest_received unless has866
    has867 = true
    mhld_results << mhld_field.display(latest_received)
  end
  mhld_field.fields868.each do |f|
    mhld_field.library_has = "Index: #{library_has(f)}"
    latest_received = mhld_field.latest_received unless has866
    has868 = true
    mhld_results << mhld_field.display(latest_received)
  end
  if !has866 && !has867 && !has868
    if mhld_field.df852has_equals_sf
      latest_received = mhld_field.latest_received
    end
    mhld_results << mhld_field.display(latest_received)
  end

  mhld_results
end

def library_has(field)
  [field['a'], field['z']].compact.join(' ')
end

to_field 'bookplates_display' do |record, accumulator|
  Traject::MarcExtractor.new('979').collect_matching_lines(record) do |field, spec, extractor|
    file = field['c']
    next if file =~ /no content metadata/i
    fund_name = field['f']
    druid = field['b'].split(':')
    text = field['d']
    accumulator << [fund_name, druid[1], file, text].join(' -|- ')
  end
end
to_field 'fund_facet' do |record, accumulator|
  Traject::MarcExtractor.new('979').collect_matching_lines(record) do |field, spec, extractor|
    file = field['c']
    next if file =~ /no content metadata/i
    druid = field['b'].split(':')
    accumulator << druid[1]
  end
end
#
# # Digitized Items Fields
to_field 'managed_purl_urls' do |record, accumulator|
  Traject::MarcExtractor.new('856u').collect_matching_lines(record) do |field, spec, extractor|
    if field['x'] =~ /SDR-PURL/
      accumulator.concat extractor.collect_subfields(field, spec)
    end
  end
end

to_field 'collection', literal('sirsi')
to_field 'collection' do |record, accumulator|
  Traject::MarcExtractor.new('856x').collect_matching_lines(record) do |field, spec, extractor|
    subfields = extractor.collect_subfields(field, spec)
    next unless subfields[0] == 'SDR-PURL' && subfields[1] == 'item'

    accumulator.concat(subfields.slice(2..-1).map do |v|
      v.split(':')
    end.select do |(type, _druid, _id, _title)|
      type == 'collection'
    end.map do |(_type, druid, id, _title)|
      id.empty? ? druid : id
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
      id.empty? ? druid : id
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
# Course Reserves Fields
REZ_DESK_2_BLDG_FACET = Traject::TranslationMap.new('rez_desk_2_bldg_facet').freeze
REZ_DESK_2_REZ_LOC_FACET = Traject::TranslationMap.new('rez_desk_2_rez_loc_facet').freeze
DEPT_CODE_2_USER_STR = Traject::TranslationMap.new('dept_code_2_user_str').freeze
LOAN_CODE_2_USER_STR = Traject::TranslationMap.new('loan_code_2_user_str').freeze
LIB_2_BLDG_FACET = Traject::TranslationMap.new('library_code_translations').freeze

to_field 'crez_instructor_search' do |record, accumulator, context|
  id = context.output_hash['id']&.first
  course_reserves = reserves_lookup[id]
  next unless course_reserves
  course_reserves.each do |row|
    accumulator << row[:instructor_name]
  end
end

to_field 'crez_course_name_search' do |record, accumulator, context|
  id = context.output_hash['id']&.first
  course_reserves = reserves_lookup[id]
  next unless course_reserves
  course_reserves.each do |row|
    accumulator << row[:course_name]
  end
end

to_field 'crez_course_id_search' do |record, accumulator, context|
  id = context.output_hash['id']&.first
  course_reserves = reserves_lookup[id]
  next unless course_reserves
  course_reserves.each do |row|
    accumulator << row[:course_id]
  end
end

to_field 'crez_desk_facet' do |record, accumulator, context|
  id = context.output_hash['id']&.first
  course_reserves = reserves_lookup[id]
  next unless course_reserves
  course_reserves.each do |row|
    accumulator << REZ_DESK_2_REZ_LOC_FACET[row[:rez_desk]]
  end
end

to_field 'crez_dept_facet' do |record, accumulator, context|
  id = context.output_hash['id']&.first
  course_reserves = reserves_lookup[id]
  next unless course_reserves
  course_reserves.each do |row|
    dept = row[:course_id].split('-')[0].split(' ')[0]
    accumulator << DEPT_CODE_2_USER_STR[dept]
  end
end

to_field 'crez_course_info' do |record, accumulator, context|
  id = context.output_hash['id']&.first
  course_reserves = reserves_lookup[id]
  next unless course_reserves
  course_reserves.each do |row|
    accumulator << %i[course_id course_name instructor_name].map do |sym|
      row[sym]
    end.join(' -|- ')
  end
end

each_record do |record, context|
  context.output_hash.reject { |k, v| k == 'mhld_display' || k =~ /^url_/ || k =~ /^marc/}.transform_values do |v|
    v.map! do |x|
      x.respond_to?(:strip) ? x.strip : x
    end

    v.uniq!
  end
end

# We update item_display once we have crez info
to_field 'item_display' do |record, accumulator, context|
  id = context.output_hash['id']&.first
  course_reserves = reserves_lookup[id]
  next unless course_reserves
  context.output_hash['item_display'].map! do |item_display_value|
    split_item_display = item_display_value.split('-|-')
    item_displays = []
    course_reserves.each do |row|
      next unless row[:barcode].strip == split_item_display[0].strip
      rez_desk = row[:rez_desk] || ''
      loan_period = LOAN_CODE_2_USER_STR[row[:loan_period]] || ''
      course_id = row[:course_id] || ''
      suffix = [course_id, rez_desk, loan_period].join(' -|- ')
      # replace current location in existing item_display field with rez_desk
      old_val_array = item_display_value.split(' -|- ', -1)
      old_val_array[3] = rez_desk
      new_val = old_val_array.join(' -|- ')
      item_displays << new_val + ' -|- ' + suffix
    end
    # Use original item_display field if none matched
    item_displays << item_display_value if item_displays.empty?
    item_displays
  end.flatten!
end

to_field 'building_facet' do |record, accumulator, context|
  id = context.output_hash['id']&.first
  course_reserves = reserves_lookup[id]
  next unless course_reserves
  new_building_facet_vals = []

  context.output_hash['item_display'].map do |item_display_value|
    split_item_display = item_display_value.split("-|-").map(&:strip)
    course_reserves.each do |row|
      home_building = LIB_2_BLDG_FACET[split_item_display[1]]
      rez_building = REZ_DESK_2_BLDG_FACET[row[:rez_desk]]
      # Building comparison
      next if home_building == rez_building

      # Barcode comparison
      if row[:barcode].strip == split_item_display[0].strip
        if !rez_building.nil?
          new_building_facet_vals << rez_building
        else
          new_building_facet_vals << home_building
        end
      else
         new_building_facet_vals << home_building
      end
    end
  end
  context.output_hash['building_facet'] = new_building_facet_vals.uniq if new_building_facet_vals.any?
end
