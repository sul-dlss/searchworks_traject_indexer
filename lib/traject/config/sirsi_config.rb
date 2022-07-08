$LOAD_PATH << File.expand_path('../..', __dir__)

require 'traject'
require 'traject/macros/marc21_semantics'
require 'traject/readers/marc_combining_reader'
require 'traject/readers/kafka_marc_reader'
require 'traject/writers/solr_better_json_writer'
require 'call_numbers/lc'
require 'call_numbers/dewey'
require 'call_numbers/other'
require 'call_numbers/shelfkey'
require 'sirsi_holding'
require 'mhld_field'
require 'marc_links'
require 'utils'
require 'csv'
require 'i18n'
require 'honeybadger'
require 'digest/md5'

I18n.available_locales = [:en]

extend Traject::Macros::Marc21
extend Traject::Macros::Marc21Semantics
extend Traject::SolrBetterJsonWriter::IndexerPatch

Utils.logger = logger

ALPHABET = [*'a'..'z'].join('')
A_X = ALPHABET.slice(0, 24)
MAX_CODE_POINT = 0x10FFFF.chr(Encoding::UTF_8)
CJK_RANGE = /(\p{Han}|\p{Hangul}|\p{Hiragana}|\p{Katakana})/.freeze

indexer = self

module Constants
  EXCLUDE_FIELDS = ['w', '0', '1', '2', '5', '6', '8', '?', '=']
  NIELSEN_TAGS = { '505' => '905', '520' => '920', '586' => '986' }
  SOURCES = { 'Nielsen' => '(source: Nielsen Book Data)' }

  RELATOR_TERMS = { 'acp' => 'Art copyist',
                    'act' => 'Actor',
                    'adp' => 'Adapter',
                    'aft' => 'Author of afterword, colophon, etc.',
                    'anl' => 'Analyst',
                    'anm' => 'Animator',
                    'ann' => 'Annotator',
                    'ant' => 'Bibliographic antecedent',
                    'app' => 'Applicant',
                    'aqt' => 'Author in quotations or text abstracts',
                    'arc' => 'Architect',
                    'ard' => 'Artistic director ',
                    'arr' => 'Arranger',
                    'art' => 'Artist',
                    'asg' => 'Assignee',
                    'asn' => 'Associated name',
                    'att' => 'Attributed name',
                    'auc' => 'Auctioneer',
                    'aud' => 'Author of dialog',
                    'aui' => 'Author of introduction',
                    'aus' => 'Author of screenplay',
                    'aut' => 'Author',
                    'bdd' => 'Binding designer',
                    'bjd' => 'Bookjacket designer',
                    'bkd' => 'Book designer',
                    'bkp' => 'Book producer',
                    'bnd' => 'Binder',
                    'bpd' => 'Bookplate designer',
                    'bsl' => 'Bookseller',
                    'ccp' => 'Conceptor',
                    'chr' => 'Choreographer',
                    'clb' => 'Collaborator',
                    'cli' => 'Client',
                    'cll' => 'Calligrapher',
                    'clt' => 'Collotyper',
                    'cmm' => 'Commentator',
                    'cmp' => 'Composer',
                    'cmt' => 'Compositor',
                    'cng' => 'Cinematographer',
                    'cnd' => 'Conductor',
                    'cns' => 'Censor',
                    'coe' => 'Contestant -appellee',
                    'col' => 'Collector',
                    'com' => 'Compiler',
                    'cos' => 'Contestant',
                    'cot' => 'Contestant -appellant',
                    'cov' => 'Cover designer',
                    'cpc' => 'Copyright claimant',
                    'cpe' => 'Complainant-appellee',
                    'cph' => 'Copyright holder',
                    'cpl' => 'Complainant',
                    'cpt' => 'Complainant-appellant',
                    'cre' => 'Creator',
                    'crp' => 'Correspondent',
                    'crr' => 'Corrector',
                    'csl' => 'Consultant',
                    'csp' => 'Consultant to a project',
                    'cst' => 'Costume designer',
                    'ctb' => 'Contributor',
                    'cte' => 'Contestee-appellee',
                    'ctg' => 'Cartographer',
                    'ctr' => 'Contractor',
                    'cts' => 'Contestee',
                    'ctt' => 'Contestee-appellant',
                    'cur' => 'Curator',
                    'cwt' => 'Commentator for written text',
                    'dfd' => 'Defendant',
                    'dfe' => 'Defendant-appellee',
                    'dft' => 'Defendant-appellant',
                    'dgg' => 'Degree grantor',
                    'dis' => 'Dissertant',
                    'dln' => 'Delineator',
                    'dnc' => 'Dancer',
                    'dnr' => 'Donor',
                    'dpc' => 'Depicted',
                    'dpt' => 'Depositor',
                    'drm' => 'Draftsman',
                    'drt' => 'Director',
                    'dsr' => 'Designer',
                    'dst' => 'Distributor',
                    'dtc' => 'Data contributor ',
                    'dte' => 'Dedicatee',
                    'dtm' => 'Data manager ',
                    'dto' => 'Dedicator',
                    'dub' => 'Dubious author',
                    'edt' => 'Editor',
                    'egr' => 'Engraver',
                    'elg' => 'Electrician ',
                    'elt' => 'Electrotyper',
                    'eng' => 'Engineer',
                    'etr' => 'Etcher',
                    'exp' => 'Expert',
                    'fac' => 'Facsimilist',
                    'fld' => 'Field director ',
                    'flm' => 'Film editor',
                    'fmo' => 'Former owner',
                    'fpy' => 'First party',
                    'fnd' => 'Funder',
                    'frg' => 'Forger',
                    'gis' => 'Geographic information specialist ',
                    'grt' => 'Graphic technician',
                    'hnr' => 'Honoree',
                    'hst' => 'Host',
                    'ill' => 'Illustrator',
                    'ilu' => 'Illuminator',
                    'ins' => 'Inscriber',
                    'inv' => 'Inventor',
                    'itr' => 'Instrumentalist',
                    'ive' => 'Interviewee',
                    'ivr' => 'Interviewer',
                    'lbr' => 'Laboratory ',
                    'lbt' => 'Librettist',
                    'ldr' => 'Laboratory director ',
                    'led' => 'Lead',
                    'lee' => 'Libelee-appellee',
                    'lel' => 'Libelee',
                    'len' => 'Lender',
                    'let' => 'Libelee-appellant',
                    'lgd' => 'Lighting designer',
                    'lie' => 'Libelant-appellee',
                    'lil' => 'Libelant',
                    'lit' => 'Libelant-appellant',
                    'lsa' => 'Landscape architect',
                    'lse' => 'Licensee',
                    'lso' => 'Licensor',
                    'ltg' => 'Lithographer',
                    'lyr' => 'Lyricist',
                    'mcp' => 'Music copyist',
                    'mfr' => 'Manufacturer',
                    'mdc' => 'Metadata contact',
                    'mod' => 'Moderator',
                    'mon' => 'Monitor',
                    'mrk' => 'Markup editor',
                    'msd' => 'Musical director',
                    'mte' => 'Metal-engraver',
                    'mus' => 'Musician',
                    'nrt' => 'Narrator',
                    'opn' => 'Opponent',
                    'org' => 'Originator',
                    'orm' => 'Organizer of meeting',
                    'oth' => 'Other',
                    'own' => 'Owner',
                    'pat' => 'Patron',
                    'pbd' => 'Publishing director',
                    'pbl' => 'Publisher',
                    'pdr' => 'Project director',
                    'pfr' => 'Proofreader',
                    'pht' => 'Photographer',
                    'plt' => 'Platemaker',
                    'pma' => 'Permitting agency',
                    'pmn' => 'Production manager',
                    'pop' => 'Printer of plates',
                    'ppm' => 'Papermaker',
                    'ppt' => 'Puppeteer',
                    'prc' => 'Process contact',
                    'prd' => 'Production personnel',
                    'prf' => 'Performer',
                    'prg' => 'Programmer',
                    'prm' => 'Printmaker',
                    'pro' => 'Producer',
                    'prt' => 'Printer',
                    'pta' => 'Patent applicant',
                    'pte' => 'Plaintiff -appellee',
                    'ptf' => 'Plaintiff',
                    'pth' => 'Patent holder',
                    'ptt' => 'Plaintiff-appellant',
                    'rbr' => 'Rubricator',
                    'rce' => 'Recording engineer',
                    'rcp' => 'Recipient',
                    'red' => 'Redactor',
                    'ren' => 'Renderer',
                    'res' => 'Researcher',
                    'rev' => 'Reviewer',
                    'rps' => 'Repository',
                    'rpt' => 'Reporter',
                    'rpy' => 'Responsible party',
                    'rse' => 'Respondent-appellee',
                    'rsg' => 'Restager',
                    'rsp' => 'Respondent',
                    'rst' => 'Respondent-appellant',
                    'rth' => 'Research team head',
                    'rtm' => 'Research team member',
                    'sad' => 'Scientific advisor',
                    'sce' => 'Scenarist',
                    'scl' => 'Sculptor',
                    'scr' => 'Scribe',
                    'sds' => 'Sound designer',
                    'sec' => 'Secretary',
                    'sgn' => 'Signer',
                    'sht' => 'Supporting host',
                    'sng' => 'Singer',
                    'spk' => 'Speaker',
                    'spn' => 'Sponsor',
                    'spy' => 'Second party',
                    'srv' => 'Surveyor',
                    'std' => 'Set designer',
                    'stl' => 'Storyteller',
                    'stm' => 'Stage manager',
                    'stn' => 'Standards body',
                    'str' => 'Stereotyper',
                    'tcd' => 'Technical director',
                    'tch' => 'Teacher',
                    'ths' => 'Thesis advisor',
                    'trc' => 'Transcriber',
                    'trl' => 'Translator',
                    'tyd' => 'Type designer',
                    'tyg' => 'Typographer',
                    'vdg' => 'Videographer',
                    'voc' => 'Vocalist',
                    'wam' => 'Writer of accompanying material',
                    'wdc' => 'Woodcutter',
                    'wde' => 'Wood -engraver',
                    'wit' => 'Witness' }
end

settings do
  provide 'writer_class_name', 'Traject::SolrBetterJsonWriter'
  provide 'solr.url', ENV['SOLR_URL']
  provide 'solr.version', ENV['SOLR_VERSION']
  provide 'processing_thread_pool', ENV['NUM_THREADS']
  if ENV['KAFKA_TOPIC']
    provide "reader_class_name", "Traject::KafkaMarcReader"
    kafka = Kafka.new(ENV.fetch('KAFKA', 'localhost:9092').split(','))
    consumer = kafka.consumer(group_id: ENV.fetch('KAFKA_CONSUMER_GROUP_ID', "traject_#{ENV['KAFKA_TOPIC']}"))
    consumer.subscribe(ENV['KAFKA_TOPIC'])
    provide 'kafka.consumer', consumer
  else
    provide "reader_class_name", "Traject::MarcCombiningReader"
  end

  provide 'allow_duplicate_values',  false
  provide 'skip_empty_item_display', ENV['SKIP_EMPTY_ITEM_DISPLAY'].to_i
  provide 'solr_writer.commit_on_close', true
  provide 'mapping_rescue', (lambda do |context, e|
    Honeybadger.notify(e, context: { record: context.record_inspect, index_step: context.index_step.inspect })

    indexer.send(:default_mapping_rescue).call(context, e)
  end)

  if defined?(JRUBY_VERSION)
    require 'traject/marc4j_reader'
    provide "marc4j_reader.permissive", true
    require 'traject/manticore_http_client'
    provide 'solr_json_writer.http_client', Traject::ManticoreHttpClient.new
  else
    provide 'solr_json_writer.http_client', HTTPClient.new.tap { |x| x.receive_timeout = 600 }
  end
  provide 'solr_json_writer.skippable_exceptions', [HTTPClient::TimeoutError, StandardError]
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

def reserves_lookup
  settings['reserves_path_mtime'] ||= Time.at(0)

  reserves_file = settings['reserves_file']
  reserves_file ||= begin
    crez_dir = settings['reserves_path']
    crez_dir ||= "/data/sirsi/#{ENV.fetch('SIRSI_SERVER', 'bodoni')}/crez"

    if File.exist? crez_dir
      reserves_path_mtime = File.mtime(crez_dir)

      if reserves_path_mtime > settings['reserves_path_mtime']
        logger.info("#{crez_dir} changed (#{reserves_path_mtime})")
        settings['reserves_path_mtime'] = reserves_path_mtime
        crez_file = Dir.glob(File.expand_path('*', crez_dir)).max_by { |f| File.mtime(f) }

        if settings['latest_reserves_file'] != crez_file
          logger.info("Found new crez file: #{crez_file}")
          settings['reserves_data'] = nil
          settings['latest_reserves_file'] = crez_file
        end
      end
      settings['latest_reserves_file']
    end
  end

  return {} unless reserves_file

  settings['reserves_data'] ||= begin
    logger.info("Loading new crez data from #{reserves_file}")
    reserves_data ||= {}
    csv_options = {
      col_sep: '|', headers: 'rez_desk|resctl_exp_date|resctl_status|ckey|barcode|home_loc|curr_loc|item_rez_status|loan_period|rez_expire_date|rez_stage|course_id|course_name|term|instructor_name',
      header_converters: :symbol, quote_char: "\x00"
    }

    CSV.foreach(reserves_file, **csv_options) do |row|
      if row[:item_rez_status] == 'ON_RESERVE'
        ckey = row[:ckey]
        crez_value = reserves_data[ckey] || []
        reserves_data[ckey] = crez_value << row
      end
    end

    reserves_data
  end
end

each_record do |record, context|
  context.clipboard[:benchmark_start_time] = Time.now
end

each_record do |record|
  puts record if ENV['q']
end

##
# Skip records that have a delete field
each_record do |record, context|
  if record[:delete]
    context.output_hash['id'] = [record[:id]]
    context.skip!('Delete')
  end
end

each_record do |record, context|
  context.skip!('Incomplete record') if record['245'] && record['245']['a'] == '**REQUIRED FIELD**'
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
  accumulator << (SolrMarcStyleFastXMLWriter.single_record_document(record, include_namespace: true) + "\n")
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

def get_marc_vernacular(marc,original_field)
  return_text = []
  link = parse_linkage(original_field)
  return unless link[:number]

  marc.select { |f| link[:tag] == f.tag && parse_linkage(f)[:number] == link[:number] }.each do |field|
    field.each do |sub|
      next if Constants::EXCLUDE_FIELDS.include?(sub.code) || sub.code == '4'
      return_text << sub.value
    end
  end

  return return_text.join(" ") unless return_text.empty?
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

def works_struct(record, tags, indicator2: nil, link_codes: %w[a d f k l m n o p r s t].freeze, text_codes: %w[h i x 3].freeze)

  Traject::MarcExtractor.cached(tags).collect_matching_lines(record) do |field, spec, extractor|
    next if ['700', '710', '711'].include?(field.tag) && (!field['t'] || field['t'].empty?)

    result = {
      before: [],
      inside: [],
      after: []
    }

    subfields_before = field.subfields.take_while { |subfield| !link_codes.include?(subfield.code) }
    subfields_after = field.subfields.reverse.take_while { |subfield| !link_codes.include?(subfield.code) }.reverse

    result[:before] = subfields_before.select do |subfield|
      text_codes.include?(subfield.code)
    end

    result[:inside] = field.subfields.slice(subfields_before.length..(-1 * (subfields_after.length + 1)))

    result[:after] = subfields_after.select do |subfield|
      text_codes.include?(subfield.code)
    end

    {
      link: result[:inside].map(&:value).join(' '),
      search: result[:inside].reject { |subfield| text_codes.include?(subfield.code) }.map(&:value).join(' '),
      pre_text: result[:before].map(&:value).join(' '),
      post_text: result[:after].map(&:value).join(' '),
      authorities: field.subfields.select { |x| x.code == '0' }.map(&:value),
      rwo: field.subfields.select { |x| x.code == '1' }.map(&:value)
    }
  end
end

to_field 'author_authorities_ssim', extract_marc('1001:1000:1100:1101:1110:1111:7000:7001:7100:7101:7110:7111:7200:7201:7300:7301:7400:7401')

def linked_author_struct(record, tag)
  Traject::MarcExtractor.cached(tag).collect_matching_lines(record) do |field, spec, extractor|
    subfields = field.subfields.reject { |subfield| Constants::EXCLUDE_FIELDS.include?(subfield.code) }
    {
      link: subfields.select { |subfield| linked?(tag, subfield) }.map(&:value).join(' '),
      search: subfields.select { |subfield| linked?(tag, subfield) }.reject { |subfield| subfield.code == 't' }.map(&:value).join(' '),
      post_text: subfields.reject { |subfield| subfield.code == 'i' }.select { |subfield| %w[e 4].include?(subfield.code) || !linked?(tag, subfield) }.each { |subfield| subfield.value = Constants::RELATOR_TERMS[subfield.value] || subfield.value if subfield.code == '4' }.map(&:value).join(' '),
      authorities: field.subfields.select { |x| x.code == '0' }.map(&:value),
      rwo: field.subfields.select { |x| x.code == '1' }.map(&:value)
    }.reject { |k, v| v.empty? }
  end
end

def linked_contributors_struct(record)
  contributors = []
  vern_fields = []

  Traject::MarcExtractor.cached('700:710:711:720', alternate_script: :only).each_matching_line(record) do |f|
    vern_fields << f if !f['t'] || f['t'].empty?
  end

  Traject::MarcExtractor.cached('700:710:711:720', alternate_script: false).collect_matching_lines(record) do |field, spec, extractor|
    if !field['t'] || field['t'].empty?
      link = parse_linkage(field)
      vern_field = vern_fields.find { |f| parse_linkage(f)[:number] == link[:number] } if field['6']

      contributor = assemble_contributor_data_struct(field)
      contributor[:vern] = assemble_contributor_data_struct(vern_field) if vern_field

      contributors << contributor
    end
  end

  vern_fields.each do |field, _spec, _extractor|
    link = parse_linkage(field)
    next unless link[:number] == '00'

    contributors << {
      vern: assemble_contributor_data_struct(field)
    }
  end

  contributors
end

def parse_linkage(field)
  return {} unless field && field['6']

  tag_and_number, script_id, field_orientation = field['6'].split('/')

  tag, number = tag_and_number.split('-', 2)

  { tag: tag, number: number, script_id: script_id, field_orientation: field_orientation }
end

def assemble_contributor_data_struct(field)
  link_text = []
  relator_text = []
  extra_text = []
  before_text = []
  field.each do |subfield|
    next if Constants::EXCLUDE_FIELDS.include?(subfield.code)
    if subfield.code == "e"
      relator_text << subfield.value
    elsif subfield.code == "4"
      relator_text << Constants::RELATOR_TERMS[subfield.value] || subfield.value
    elsif field.tag == '711' && subfield.code == 'j'
      extra_text << subfield.value
    elsif subfield.code != "e" and subfield.code != "4"
      link_text << subfield.value
    end
  end

  {
    link: link_text.join(' '),
    search: link_text.join(' '),
    pre_text: before_text.join(' '),
    post_text: relator_text.join(' ') + extra_text.join(' '),
    authorities: field.subfields.select { |x| x.code == '0' }.map(&:value),
    rwo: field.subfields.select { |x| x.code == '1' }.map(&:value)
  }
end

def linked?(tag, subfield)
  case tag
  when '100', '110'
    !%w[e i 4].include?(subfield.code) # exclude 100/110 $e $i $4
  when '111'
    !%w[j 4].include?(subfield.code) # exclude 111 $j $4
  end
end

# Custom method cribbed from Traject::Macros::Marc21Semantics.marc_sortable_author
# https://github.com/traject/traject/blob/0914a396306c2489a7e270f33793ca76665f8f19/lib/traject/macros/marc21_semantics.rb#L51-L88
# Port from Solrmarc:MarcUtils#getSortableAuthor wasn't accurate
# This method differs in that:
#  245 field returned independent of 240 being present
#  punctuation actually gets stripped
#  subfields to use specified in passed parameter
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
to_field "topic_subx_search", extract_marc("600x:610x:611x:630x:647x:650x:651x:655x:656x:657x:690x:691x:696x:697x:698x:699x", alternate_script: false)
to_field "vern_topic_subx_search", extract_marc("600xx:610xx:611xx:630xx:647xx:650xx:651xx:655xx:656xx:657xx:690xx:691xx:696xx:697xx:698xx:699xx", alternate_script: :only)
to_field "geographic_search", extract_marc("651abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw", alternate_script: false)
to_field "vern_geographic_search", extract_marc("651abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw:691abcdefghijklmnopqrstuw", alternate_script: :only)
to_field "geographic_subz_search", extract_marc("600z:610z:630z:647z:650z:651z:654z:655z:656z:657z:690z:691z:696z:697z:698z:699z", alternate_script: false)

to_field "vern_geographic_subz_search", extract_marc("600zz:610zz:630zz:647zz:650zz:651zz:654zz:655zz:656zz:657zz:690zz:691zz:696zz:697zz:698zz:699zz", alternate_script: :only)
to_field "subject_other_search", extract_marc(%w(600 610 611 630 647 655 656 657 658 696 697 698 699).map { |c| "#{c}abcdefghijklmnopqrstuw"}.join(':'), alternate_script: false) do |record, accumulator|
  accumulator.reject! { |v| v == 'nomesh' }
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

  Utils.balance_parentheses(new_value)
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

def clean_marc_008_date(year, u_replacement: '0')
  return unless year =~ /(\d{4}|\d{3}[u-])/
  year = year.gsub(/[u-]$/, u_replacement)
  return unless (500..(Time.now.year + 10)).include? year.to_i

  return year.to_i.to_s
end

def marc_008_date(byte6values, byte_range, u_replacement)
  lambda do |record, accumulator|
    Traject::MarcExtractor.new('008', first: true).collect_matching_lines(record) do |field, spec, extractor|
      if byte6values.include? field.value[6]
        year = clean_marc_008_date(field.value[byte_range], u_replacement: u_replacement)
        accumulator << year if year
      end
    end
  end
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
    if %w[0 1].include?(field.indicator2)
      # Similar logic exists in the link_is_fulltext? method in the MarcLinks class.
      # They need to remain the same (or should be refactored to use the same code in the future)
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

to_field 'marc_links_struct' do |record, accumulator|
  Traject::MarcExtractor.new('856').collect_matching_lines(record) do |field, spec, extractor|
    result = MarcLinks::Processor.new(field).as_h
    accumulator << result if result
  end
end

to_field 'marc_links_struct' do |record, accumulator|
  Traject::MarcExtractor.new('956').collect_matching_lines(record) do |field, spec, extractor|
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
      marc035_with_m_suffix << data.sub(/^\(OCoLC-M\)\s*/, '')
    elsif data.start_with?('(OCoLC)')
      marc035_without_m_suffix << data.sub(/^\(OCoLC\)\s*/, '')
    end
  end.flatten.compact.uniq

  marc079 = Traject::MarcExtractor.new('079a', separator: nil).extract(record).map do |data|
    next unless regex_to_extract_data_from_a_string(data, /\A(?:ocm)|(?:ocn)|(?:on)/)
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
to_field 'access_facet' do |record, accumulator, context|
  online_locs = ['E-RECVD', 'E-RESV', 'ELECTR-LOC', 'INTERNET', 'KIOST', 'ONLINE-TXT', 'RESV-URL', 'WORKSTATN']
  on_order_ignore_locs = %w[ENDPROCESS INPROCESS LAC SPEC-INPRO]
  holdings(record, context).each do |holding|
    next if holding.skipped?

    field = holding.tag

    if online_locs.include?(field['k']) || online_locs.include?(field['l']) || holding.e_call_number?
      accumulator << 'Online'
    elsif field['a'] =~ /^XX/ && (field['k'] == 'ON-ORDER' || (!field['k'].nil? && !field['k'].empty? && (on_order_ignore_locs & [field['k'], field['l']]).empty? && field['m'] != 'HV-ARCHIVE'))
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
  next if context.output_hash['format_main_ssim'].nil?

  context.output_hash['format_main_ssim'].delete('Other') if context.output_hash['format_main_ssim']
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
  if context.output_hash['format_main_ssim'] && context.output_hash['format_main_ssim'].include?('Database')
    translation_map = Traject::TranslationMap.new('db_subjects_map')
    accumulator.replace translation_map.translate_array(accumulator).flatten
  else
    accumulator.replace([])
  end
end

to_field 'db_az_subject' do |record, accumulator, context|
  if context.output_hash['format_main_ssim'] && context.output_hash['format_main_ssim'].include?('Database')
    if record['099'].nil?
      accumulator << 'Uncategorized'
    end
  end
end

to_field "physical", extract_marc("3003abcefg", alternate_script: false)
to_field "vern_physical", extract_marc("3003abcefg", alternate_script: :only)

to_field "toc_search", extract_marc("905art:505art", alternate_script: false)
to_field "vern_toc_search", extract_marc("505art", alternate_script: :only)

# sometimes we find vernacular script in the 505 anyway :shrug:
to_field 'vern_toc_search' do |_record, accumulator, context|
  next unless context.output_hash['toc_search']

  accumulator.replace(context.output_hash['toc_search'].select { |value| value.match?(CJK_RANGE) } )
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

  tag = '905' if marc['905'] && (marc['505'].nil? or (marc['505']["t"].nil? and marc['505']["r"].nil?))
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
        elsif sub_field.code == "1" && !Constants::SOURCES[sub_field.value.strip].nil?
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

      data << buffer.map { |w| w.strip unless w.strip.empty? }.compact.join(' ') unless buffer.empty?
      fields << data

      vernacular = get_marc_vernacular(marc,field)
      vern << split_toc_chapters(vernacular).map { |w| w.strip unless w.strip.empty? }.compact unless vernacular.nil?
    end
  end

  unmatched_vern_fields = get_unmatched_vernacular(marc, '505')
  unless unmatched_vern_fields.nil?
    unmatched_vern_fields.each do |vern_field|
      unmatched_vern << regex_split(vern_field, /[^\S]--[^\S]/).map { |w| w.strip unless w.strip.empty? }.compact
    end
  end

  new_vern = vern unless vern.empty?
  new_fields = fields unless fields.empty?
  new_unmatched_vern = unmatched_vern unless unmatched_vern.empty?
  accumulator << {:label=>"Contents",:fields=>new_fields,:vernacular=>new_vern,:unmatched_vernacular=>new_unmatched_vern} unless (new_fields.nil? and new_vern.nil? and new_unmatched_vern.nil?)
end

def split_toc_chapters(value)
  formatted_chapter_regexes = [
    /[^\S]--[^\S]/, # this is the normal, expected MARC delimiter
    /      /, # but a bunch of eResources like to use whitespace
    /--[^\S]/, # or omit the leading whitespace
    /[^\S]\.-[^\S]/, # or a .-
    /(?=(?:Chapter|Section|Appendix|Part|v\.) \d+[:\.-]?\s+)/i, # and sometimes not even that; here are some common patterns that suggest chapters
    /(?=(?:Appendix|Section|Chapter) [XVI]+[\.-]?)/i,
    /(?=[^\d](?:\d+[:\.-]\s+))/i, # but sometimes it's just a number with something after it
    /(?=(?:\s{2,}\d+\s+))/i # or even just a number with a little extra whitespace in front of it
  ]
  formatted_chapter_regexes.each do |regex|
    chapters = value.split(regex).map { |w| w.strip unless w.strip.empty? }.compact
    # if the split found a match and actually split the string, we are done
    return chapters if chapters.length > 1
  end
  [value]
end

# work-around for https://github.com/jruby/jruby/issues/4868
def regex_split(str, regex)
  str.split(regex).to_a
end

# work-around for https://github.com/jruby/jruby/issues/4868
def regex_to_extract_data_from_a_string(str, regex)
  str[regex]
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
  if matching_fields.any?
    matching_fields.each do |field|

      field_text = []
      field.each do |sub_field|
        if sub_field.code == "u" and sub_field.value.strip =~ /^https*:\/\//
          field_text << { link: sub_field.value }
        elsif sub_field.code == "1"
          field_text << { source: Constants::SOURCES[sub_field.value] }
        elsif !(Constants::EXCLUDE_FIELDS + ['x']).include?(sub_field.code)
          field_text << sub_field.value unless sub_field.code == 'a' && sub_field.value[0,1] == "%"
        end
      end
      fields << { field: field_text, vernacular: get_marc_vernacular(marc, field) } unless field_text.empty?
    end
  else
    unmatched_vern = get_unmatched_vernacular(marc,tag)
  end

  accumulator << { label: label, fields: fields, unmatched_vernacular: unmatched_vern } unless fields.empty? && unmatched_vern.nil?
end

def get_unmatched_vernacular(marc,tag)
  return [] unless marc['880']

  fields = []

  marc.select { |f| f.tag == '880' }.each do |field|
    text = []
    link = parse_linkage(field)

    next unless link[:number] == '00' && link[:tag] == tag
    field.each do |sub|
      next if Constants::EXCLUDE_FIELDS.include?(sub.code)
      text << sub.value
    end

    fields << text.join(' ') unless text.empty?
  end

  return fields unless fields.empty?
end


to_field "context_search", extract_marc("518a", alternate_script: false)
to_field "vern_context_search", extract_marc("518aa", alternate_script: :only)
to_field "summary_search", extract_marc("920ab:520ab", alternate_script: false)
to_field "vern_summary_search", extract_marc("520ab", alternate_script: :only)

# sometimes we find vernacular script in the 520 anyway :shrug:
to_field 'vern_summary_search' do |_record, accumulator, context|
  next unless context.output_hash['summary_search']

  accumulator.replace(context.output_hash['summary_search'].select { |value| value.match?(CJK_RANGE) } )
end

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

#
# # Call Number Fields

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
  context.clipboard[:holdings] ||= begin
    holdings = []
    record.each_by_tag('999') do |item|
      holdings << SirsiHolding.new(
        call_number: (item['a'] || '').strip,
        current_location: item['k'],
        home_location: item['l'],
        library: item['m'],
        scheme: item['w'],
        type: item['t'],
        barcode: item['i'],
        tag: item
      )
    end
    holdings
  end
end

to_field 'callnum_facet_hsim' do |record, accumulator, context|
  holdings(record, context).each do |holding|
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
    letters = regex_to_extract_data_from_a_string(cn, /^[A-Z]+/)

    next unless first_letter && translation_map[first_letter]

    accumulator << [
      'LC Classification',
      translation_map[first_letter],
      translation_map[letters]
    ].compact.join('|')
  end
end

to_field 'callnum_facet_hsim' do |record, accumulator, context|
  holdings(record, context).each do |holding|
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
    ].compact.join('|')
  end

  accumulator.uniq!
end

to_field 'callnum_facet_hsim', extract_marc('050ab') do |record, accumulator, context|
  accumulator.replace([]) and next if context.output_hash['callnum_facet_hsim'] || (record['086'] || {})['a']

  accumulator.map! do |cn|
    next unless cn =~ SirsiHolding::CallNumber::VALID_LC_REGEX

    first_letter = cn[0, 1].upcase
    letters = regex_to_extract_data_from_a_string(cn, /^[A-Z]+/)

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

to_field 'callnum_facet_hsim', extract_marc('090ab') do |record, accumulator, context|
  accumulator.replace([]) and next if context.output_hash['callnum_facet_hsim'] || (record['086'] || {})['a']
  accumulator.map! do |cn|
    next unless cn =~ SirsiHolding::CallNumber::VALID_LC_REGEX

    first_letter = cn[0, 1].upcase
    letters = regex_to_extract_data_from_a_string(cn, /^[A-Z]+/)

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

to_field 'callnum_facet_hsim' do |record, accumulator, context|
  marc_086 = record.fields('086')
  gov_doc_values = []
  holdings(record, context).each do |holding|

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


to_field 'callnum_search' do |record, accumulator, context|
  good_call_numbers = []
  holdings(record, context).each do |holding|
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

to_field 'lc_assigned_callnum_ssim', extract_marc('050ab:090ab') do |_record, accumulator, _context|
  accumulator.select! { |cn|  cn =~ SirsiHolding::CallNumber::VALID_LC_REGEX }
end

# shelfkey = custom, getShelfkeys

to_field 'shelfkey' do |record, accumulator, context|
  holdings(record, context).each do |holding|
    next if holding.skipped? || holding.shelved_by_location? || holding.lost_or_missing?
    non_skipped_or_ignored_holdings = context.clipboard[:non_skipped_or_ignored_holdings_by_library_location_call_number_type]

    stuff_in_the_same_library = Array(non_skipped_or_ignored_holdings[[holding.library, LOCATION_MAP[holding.home_location], holding.call_number_type]])

    if stuff_in_the_same_library.length > 1
      call_number_object = call_number_for_holding(record, holding, context)
      lopped_shelfkey = call_number_object.to_lopped_shelfkey

      # if we lopped the shelfkey, or if there's other stuff in the same library whose shelfkey will be lopped to this holding's shelfkey, we need to add ellipses.
      if lopped_shelfkey != call_number_object.to_shelfkey || stuff_in_the_same_library.reject { |x| x.call_number.to_s == holding.call_number.to_s }.select { |x| call_number_for_holding(record, x, context).lopped == call_number_object.lopped }.any?
        accumulator << lopped_shelfkey + " ..."
      else
        accumulator << lopped_shelfkey
      end
    else
      accumulator << call_number_for_holding(record, holding, context).to_shelfkey
    end
  end
end

# given a shelfkey (a lexicaly sortable call number), return the reverse
# shelf key - a sortable version of the call number that will give the
# reverse order (for getting "previous" call numbers in a list)
#
# return the reverse String value, mapping A --> 9, B --> 8, ...
#   9 --> A and also non-alphanum to sort properly (before or after alphanum)
to_field 'reverse_shelfkey' do |record, accumulator, context|
  holdings(record, context).each do |holding|
    next if holding.skipped? || holding.shelved_by_location? || holding.lost_or_missing?
    non_skipped_or_ignored_holdings = context.clipboard[:non_skipped_or_ignored_holdings_by_library_location_call_number_type]

    stuff_in_the_same_library = Array(non_skipped_or_ignored_holdings[[holding.library, LOCATION_MAP[holding.home_location], holding.call_number_type]])

    if stuff_in_the_same_library.length > 1
      call_number_object = call_number_for_holding(record, holding, context)
      lopped_shelfkey = call_number_object.to_lopped_reverse_shelfkey

      accumulator << lopped_shelfkey
    else
      accumulator << call_number_for_holding(record, holding, context).to_reverse_shelfkey
    end
  end
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
  non_skipped_holdings = []
  holdings(record, context).each do |holding|
    next if holding.skipped? || holding.bad_lc_lane_call_number? || holding.ignored_call_number?

    non_skipped_holdings << holding
  end

  next if non_skipped_holdings.length == 0

  if non_skipped_holdings.length == 1
    accumulator << non_skipped_holdings.first.barcode
    next
  end

  # Prefer GREEN home library, and then any other location prioritized by library code
  holdings_by_library = non_skipped_holdings.group_by { |x| x.library }
  chosen_holdings = holdings_by_library['GREEN'] || holdings_by_library[holdings_by_library.keys.sort.first]

  # Prefer LC over Dewey over SUDOC over Alphanum over Other call number types
  chosen_holdings_by_callnumber_type = chosen_holdings.group_by(&:call_number_type)
  preferred_callnumber_scheme_holdings = chosen_holdings_by_callnumber_type['LC'] || chosen_holdings_by_callnumber_type['DEWEY'] || chosen_holdings_by_callnumber_type['SUDOC'] || chosen_holdings_by_callnumber_type['ALPHANUM'] || chosen_holdings_by_callnumber_type.values.first

  preferred_callnumber_holdings_by_call_number = preferred_callnumber_scheme_holdings.group_by do |holding|
    call_number_object = call_number_for_holding(record, holding, context)

    if preferred_callnumber_scheme_holdings.count { |y| y.home_location == holding.home_location } > 1
      call_number_object.lopped
    else
      call_number_object.call_number
    end
  end

  # Prefer the items with the most item for the lopped call number
  callnumber_with_the_most_items = preferred_callnumber_holdings_by_call_number.max_by { |k, v| v.length }.last

  # If there's a tie, prefer the one with the shortest call number
  checking_for_ties_holdings = preferred_callnumber_holdings_by_call_number.select { |k, v| v.length == callnumber_with_the_most_items.length }
  callnumber_with_the_most_items = checking_for_ties_holdings.min_by do |lopped_call_number, _holdings|
    lopped_call_number.length
  end.last if checking_for_ties_holdings.length > 1

  # Prefer items with the first volume sort key
  holding_with_the_most_recent_shelfkey = callnumber_with_the_most_items.min_by do |holding|
    call_number_object = call_number_for_holding(record, holding, context)
    call_number_object.to_volume_sort
  end
  accumulator << holding_with_the_most_recent_shelfkey.barcode
end

to_field 'preferred_barcode' do |record, accumulator, context|
  next if context.output_hash['preferred_barcode']
  next unless record['050'] || record['090'] || record['086']

  non_skipped_holdings = []
  holdings(record, context).each do |holding|
    next if holding.skipped?

    non_skipped_holdings << holding
  end

  online_locs = ['E-RECVD', 'E-RESV', 'ELECTR-LOC', 'INTERNET', 'KIOST', 'ONLINE-TXT', 'RESV-URL', 'WORKSTATN']

  preferred_holding = non_skipped_holdings.first do |holding|
    ignored_call_number? || online_locs.include?(holding.current_location) || online_locs.include?(holding.home_location)
  end

  accumulator << preferred_holding.barcode if preferred_holding
end

library_map = Traject::TranslationMap.new('library_map')
resv_locs = Traject::TranslationMap.new('locations_reserves_list')

to_field 'building_facet' do |record, accumulator, context|
  holdings(record, context).each do |holding|
    item = holding.tag
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

to_field 'building_location_facet_ssim' do |record, accumulator, context|
  holdings(record, context).each do |holding|
    next if holding.skipped?

    accumulator << [holding.library, '*'].join('/')
    accumulator << [holding.library, holding.home_location].join('/')
    accumulator << [holding.library, '*', 'type', holding.type].join('/')
    accumulator << [holding.library, holding.home_location, 'type', holding.type].join('/')
    if holding.current_location
      accumulator << [holding.library, '*', 'type', holding.type, 'curr', holding.current_location].join('/')
      accumulator << [holding.library, '*', 'type', '*', 'curr', holding.current_location].join('/')
      accumulator << [holding.library, holding.home_location, 'type', '*', 'curr', holding.current_location].join('/')
      accumulator << [holding.library, holding.home_location, 'type', holding.type, 'curr', holding.current_location].join('/')
    end
  end
end

to_field 'item_display' do |record, accumulator, context|
  holdings(record, context).each do |holding|
    next if holding.skipped?

    non_skipped_or_ignored_holdings = context.clipboard[:non_skipped_or_ignored_holdings_by_library_location_call_number_type]

    call_number = holding.call_number
    call_number_object = call_number_for_holding(record, holding, context)
    stuff_in_the_same_library = Array(non_skipped_or_ignored_holdings[[holding.library, LOCATION_MAP[holding.home_location], holding.call_number_type]])

    if call_number_object
      scheme = call_number_object.scheme.upcase
      # if it's a shelved-by location, use a totally different way to get the callnumber
      if holding.shelved_by_location?
        if [holding.home_location, holding.current_location].include? 'SHELBYSER'
          lopped_call_number = "Shelved by Series title"
        else
          lopped_call_number = "Shelved by title"
        end

        enumeration = holding.call_number.to_s[call_number_object.lopped.length..-1].strip unless holding.ignored_call_number?
        shelfkey = lopped_call_number.downcase
        reverse_shelfkey = CallNumbers::ShelfkeyBase.reverse(shelfkey)

        call_number = [lopped_call_number, (enumeration if enumeration)].compact.join(' ') unless holding.e_call_number?
        volume_sort = [lopped_call_number, (CallNumbers::ShelfkeyBase.reverse(CallNumbers::ShelfkeyBase.pad_all_digits(enumeration)).ljust(50, '~') if enumeration)].compact.join(' ').downcase
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
        if call_number_object.lopped == holding.call_number.to_s && stuff_in_the_same_library.reject { |x| x.call_number.to_s == holding.call_number.to_s }.select { |x| call_number_for_holding(record, x, context).lopped == call_number_object.lopped }.any?
          lopped_call_number += " ..."
          shelfkey += " ..."
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
    current_location = 'ON-ORDER' if holding.is_on_order? && holding.current_location && !holding.current_location.empty? && holding.home_location != 'ON-ORDER' && holding.home_location != 'INPROCESS'

    accumulator << [
      holding.tag['i'],
      holding.library,
      holding.home_location,
      current_location,
      holding.type,
      (lopped_call_number unless holding.ignored_call_number? && !holding.shelved_by_location?),
      (shelfkey unless holding.lost_or_missing?),
      (reverse_shelfkey.ljust(50, '~') if reverse_shelfkey && !reverse_shelfkey.empty? && !holding.lost_or_missing?),
      (call_number unless holding.ignored_call_number? && !holding.shelved_by_location?) || (call_number if holding.e_call_number? && call_number.to_s != SirsiHolding::ECALLNUM && !call_number_object.call_number),
      (volume_sort unless holding.ignored_call_number? && !holding.shelved_by_location?),
      (holding.tag['o'] if holding.tag['o'] && holding.tag['o'].upcase.start_with?('.PUBLIC.')),
      scheme
    ].join(' -|- ')
  end
end

to_field 'item_display' do |record, accumulator, context|
  next if record['999']

  order_libs = Traject::MarcExtractor.cached('596a', alternate_script: false).extract(record)
  translation_map = Traject::TranslationMap.new('library_on_order_map')

  order_libs.each do |order_lib|
    accumulator << [
      '',
      translation_map[order_lib],
      'ON-ORDER',
      'ON-ORDER',
      '',
      '',
      '',
      '',
      '',
      ''
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
      next if seq_num.nil?

      if mhld_field.most_recent863link_num < link_num || (
        mhld_field.most_recent863link_num == link_num && mhld_field.most_recent863seq_num < seq_num
      )
        mhld_field.most_recent863link_num = link_num.to_i
        mhld_field.most_recent863seq_num = seq_num.to_i
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
    accumulator << field['f']
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

##
# Course Reserves Fields
REZ_DESK_2_BLDG_FACET = Traject::TranslationMap.new('rez_desk_2_bldg_facet').freeze
REZ_DESK_2_REZ_LOC_FACET = Traject::TranslationMap.new('rez_desk_2_rez_loc_facet').freeze
DEPT_CODE_2_USER_STR = Traject::TranslationMap.new('dept_code_2_user_str').freeze
LOAN_CODE_2_USER_STR = Traject::TranslationMap.new('loan_code_2_user_str').freeze

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
  context.output_hash.reject { |k, v| k == 'mhld_display' || k == 'item_display' || k =~ /^url_/ || k =~ /^marc/}.transform_values do |v|
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
    row = course_reserves.reverse.find { |r| r[:barcode].strip == split_item_display[0].strip }

    if row
      rez_desk = row[:rez_desk] || ''
      loan_period = LOAN_CODE_2_USER_STR[row[:loan_period]] || ''
      course_id = row[:course_id] || ''
      suffix = [course_id, rez_desk, loan_period].join(' -|- ')
      # replace current location in existing item_display field with rez_desk
      old_val_array = item_display_value.split(' -|- ', -1)
      old_val_array[3] = rez_desk
      new_val = old_val_array.join(' -|- ')
      new_val + ' -|- ' + suffix
    else
      item_display_value
    end
  end.flatten!
end

to_field 'building_facet' do |_record, _accumulator, context|
  id = context.output_hash['id']&.first
  course_reserves = reserves_lookup[id]
  next unless course_reserves

  new_building_facet_vals = context.output_hash['item_display'].map do |item_display_value|
    split_item_display = item_display_value.split('-|-').map(&:strip)
    barcode = split_item_display[0].strip
    reserves_for_item = course_reserves.select { |row| row[:barcode].strip == barcode }.first

    if reserves_for_item && REZ_DESK_2_BLDG_FACET[reserves_for_item[:rez_desk]]
      REZ_DESK_2_BLDG_FACET[reserves_for_item[:rez_desk]]
    else
      # This is not dissimilar to the original building_facet mapping:
      # Try the current location first, in case it has an overridden library, and then
      # fall back on the library code.
      library_map[split_item_display[3]] || library_map[split_item_display[1]]
    end
  end

  context.output_hash['building_facet'] = new_building_facet_vals.uniq if new_building_facet_vals.any?
end

to_field 'context_source_ssi', literal('sirsi')

to_field 'context_version_ssi' do |_record, accumulator|
  accumulator << Utils.version
end

to_field 'context_input_name_ssi' do |_record, accumulator, context|
  accumulator << context.input_name
end

to_field 'context_input_modified_dtsi' do |_record, accumulator, context|
  if context.input_name && File.exist?(context.input_name)
    accumulator << File.mtime(context.input_name).utc.iso8601
  end
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

each_record do |record, context|
  context.output_hash.select { |k, _v| k =~ /_struct$/ }.each do |k, v|
    context.output_hash[k] = Array(v).map { |x| JSON.generate(x) }
  end
end

each_record do |record, context|
  t0 = context.clipboard[:benchmark_start_time]
  t1 = Time.now

  logger.debug('sirsi_config.rb') { "Processed #{context.source_record_id} (#{(t1 - t0).round(3)}s)" }
end
