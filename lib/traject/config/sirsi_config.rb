require 'traject'

ALPHABET = [*'a'..'z'].join('')
A_X = ALPHABET.slice(0, 24)

settings do
  provide 'solr.url', ENV['SOLR_URL']
  provide 'solr.version', ENV['SOLR_VERSION']
  provide 'processing_thread_pool', ENV['NUM_THREADS']
end

to_field 'id', extract_marc('001') do |_record, accumulator|
  accumulator.map! do |v|
    v.sub(/^a/, '')
  end
end

to_field 'marcxml', serialized_marc(
  format: 'xml',
  binary_escape: false,
  allow_oversized: true
)

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
  accumulator << MARC::FastXMLWriter.encode(new_record)
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
  accumulator << result.join(' ')
end

to_field 'vern_all_search' do |record, accumulator|
  keep_fields = %w[880]
  result = []
  record.each do |field|
    next unless  keep_fields.include?(field.tag)
    subfield_values = field.subfields
                           .reject { |sf| sf.code == '6' }
                           .collect(&:value)

    next unless subfield_values.length > 0

    result << subfield_values.join(' ')
  end
  accumulator << result.join(' ')
end

# Title Search Fields
to_field 'title_245a_search', extract_marc('245a', first: true)
to_field 'vern_title_245a_search', extract_marc('245a', alternate_script: :only)
to_field 'title_245_search', extract_marc('245abfgknps', first: true)
to_field 'vern_title_245_search', extract_marc('245abfgknps', alternate_script: :only)
to_field 'title_uniform_search', extract_marc('130adfgklmnoprst:240adfgklmnoprs', first: true)
to_field 'vern_title_uniform_search', extract_marc('130adfgklmnoprst:240adfgklmnoprs', first: true, alternate_script: :only)
to_field 'title_variant_search', extract_marc('210ab:222ab:242abnp:243adfgklmnoprs:246abfgnp:247abfgnp', alternate_script: false)
to_field 'vern_title_variant_search', extract_marc('210ab:222ab:242abnp:243adfgklmnoprs:246abfgnp:247abfgnp', alternate_script: :only)
to_field 'title_related_search', extract_marc('505t:700fgklmnoprst:710dfgklmnoprst:711fgklnpst:730adfgklmnoprst:740anp:760st:762st:765st:767st:770st:772st:773st:774st:775st:776st:777st:780st:785st:786st:787st:796fgklmnoprst:797dfgklmnoprst:798fgklnpst:799adfgklmnoprst')
to_field 'vern_title_related_search', extract_marc('505t:700fgklmnoprst:710dfgklmnoprst:711fgklnpst:730adfgklmnoprst:740anp:760st:762st:765st:767st:770st:772st:773st:774st:775st:776st:777st:780st:785st:786st:787st:796fgklmnoprst:797dfgklmnoprst:798fgklnpst:799adfgklmnoprst', alternate_script: :only)
# Title Display Fields
to_field 'title_245a_display', extract_marc('245a', alternate_script: false, trim_punctuation: true)
to_field 'vern_title_245a_display', extract_marc('245a', alternate_script: :only, trim_punctuation: true)
to_field 'title_245c_display', extract_marc('245c', alternate_script: false, trim_punctuation: true)
to_field 'vern_title_245c_display', extract_marc('245c', alternate_script: :only, trim_punctuation: true)
to_field 'title_display', extract_marc('245abdefghijklmnopqrstuvwxyz', alternate_script: false, trim_punctuation: true)
to_field 'vern_title_display', extract_marc('245abdefghijklmnopqrstuvwxyz', alternate_script: :only, trim_punctuation: true)
to_field 'title_full_display', extract_marc("245#{ALPHABET}", first: true, alternate_script: :false)
to_field 'vern_title_full_display', extract_marc("245#{ALPHABET}", alternate_script: :only)
to_field 'title_uniform_display', extract_marc(%w(130 240).map { |c| "#{c}#{ALPHABET}" }.join(':'), first: true, alternate_script: false)
# # ? no longer will use title_uniform_display due to author-title searching needs ? 2010-11
# TODO: Remove looks like SearchWorks is not using, confirm relevancy changes
to_field 'vern_title_uniform_display', extract_marc(%w(130 240).map { |c| "#{c}#{ALPHABET}" }.join(':'), first: true, alternate_script: :only)
# # Title Sort Field
to_field 'title_sort' do |record, accumulator|
  result = []
  result << extract_sortable_title("130#{ALPHABET}", record)
  result << extract_sortable_title('245abdefghijklmnopqrstuvwxyz', record)
  accumulator << result.join(' ').strip
end

##
# Originally cribbed from Traject::Marc21Semantics.marc_sortable_title, but by
# using algorithm from StanfordIndexer#getSortTitle.
def extract_sortable_title(fields, record)
  java7_punct = '!"#$%&\'()*+,-./:;<=>?@[\]^_`{|}~'
  Traject::MarcExtractor.new(fields).collect_matching_lines(record) do |field, spec, extractor|
    str = extractor.collect_subfields(field, spec).first
    if str.nil?
      # maybe an APPM archival record with only a 'k'
      str = field['k']
    end
    if str.nil?
      # still? All we can do is bail, I guess
      return nil
    end

    non_filing = field.indicator2.to_i
    str = str.slice(non_filing, str.length)
    str = str.delete(java7_punct).strip

    str
  end.first
end

# Series Search Fields
to_field 'series_search', extract_marc("440anpv:490av:800#{A_X}:810#{A_X}:811#{A_X}:830#{A_X}")
to_field 'vern_series_search', extract_marc("440anpv:490av:800#{A_X}:810#{A_X}:811#{A_X}:830#{A_X}", alternate_script: :only)
to_field 'series_exact_search', extract_marc('830a')

# # Author Title Search Fields
# author_title_search = custom, getAuthorTitleSearch
#
# # Author Search Fields
# # IFF relevancy of author search needs improvement, unstemmed flavors for author search
# #   (keep using stemmed version for everything search to match stemmed query)
# author_1xx_search = 100abcdgjqu:110abcdgnu:111acdegjnqu
# vern_author_1xx_search = custom, getLinkedField(100abcdgjqu:110abcdgnu:111acdegjnqu)
# author_7xx_search = 700abcdgjqu:720ae:796abcdgjqu:710abcdgnu:797abcdgnu:711acdejngqu:798acdegjnqu
# vern_author_7xx_search = custom, getLinkedField(700abcdgjqu:720ae:796abcdgjqu:710abcdgnu:797abcdgnu:711acdegjnqu:798acdegjnqu)
# author_8xx_search = 800abcdegjqu:810abcdegnu:811acdegjnqu
# vern_author_8xx_search = custom, getLinkedField(800abcdegjqu:810abcdegnu:811acdegjnqu)
# # Author Facet Fields
# author_person_facet = custom, removeTrailingPunct(100abcdq:700abcdq, [\\\\,/;:], ([A-Za-z]{4}|[0-9]{3}|\\)|\\,) )
# author_other_facet = custom, removeTrailingPunct(110abcdn:111acdn:710abcdn:711acdn, [\\\\,/;:], ([A-Za-z]{4}|[0-9]{3}|\\)|\\,) )
# # Author Display Fields
# author_person_display = custom, removeTrailingPunct(100abcdq, [\\\\,/;:], ([A-Za-z]{4}|[0-9]{3}|\\)|\\,) )
# vern_author_person_display = custom, vernRemoveTrailingPunc(100abcdq, [\\\\,/;:], ([A-Za-z]{4}|[0-9]{3}|\\)|\\,))
# author_person_full_display = custom, getAllAlphaSubfields(100)
# vern_author_person_full_display = custom, getLinkedField(100[a-z])
# author_corp_display = custom, getAllAlphaSubfields(110)
# vern_author_corp_display = custom, getLinkedField(110[a-z])
# author_meeting_display = custom, getAllAlphaSubfields(111)
# vern_author_meeting_display = custom, getLinkedField(111[a-z])
# # Author Sort Field
# author_sort = custom, getSortableAuthor
#
# # Subject Search Fields
# #  should these be split into more separate fields?  Could change relevancy if match is in field with fewer terms
to_field "topic_search", extract_marc("650abcdefghijklmnopqrstu:653abcdefghijklmnopqrstu:654abcdefghijklmnopqrstu:690abcdefghijklmnopqrstu", alternate_script: false) do |record, accumulator|
  accumulator.reject! { |v| v == 'nomesh' }
  if record['999'] && record['999']['m'] == 'LANE-MED'
    arr = []
    extract_marc('655a').call(record, arr, nil)
    accumulator.reject! { |v| arr.include? v }
  end
end

to_field "vern_topic_search", extract_marc("650abcdefghijklmnopqrstu:653abcdefghijklmnopqrstu:654abcdefghijklmnopqrstu:690abcdefghijklmnopqrstu", alternate_script: :only)
to_field "topic_subx_search", extract_marc("600x:610x:611x:630x:650x:651x:655x:656x:657x:690x:691x:696x:697x:698x:699x", alternate_script: false)
to_field "vern_topic_subx_search", extract_marc("600x:610x:611x:630x:650x:651x:655x:656x:657x:690x:691x:696x:697x:698x:699x", alternate_script: :only)
to_field "geographic_search", extract_marc("651abcdefghijklmnopqrstu:691abcdefghijklmnopqrstu:691abcdefghijklmnopqrstu", alternate_script: false)
to_field "vern_geographic_search", extract_marc("651abcdefghijklmnopqrstu:691abcdefghijklmnopqrstu:691abcdefghijklmnopqrstu", alternate_script: :only)
to_field "geographic_subz_search", extract_marc("600z:610z:630z:650z:651z:654z:655z:656z:657z:690z:691z:696z:697z:698z:699z", alternate_script: false)
to_field "vern_geographic_subz_search", extract_marc("600z:610z:630z:650z:651z:654z:655z:656z:657z:690z:691z:696z:697z:698z:699z", alternate_script: :only)
to_field "subject_other_search", extract_marc(%w(600 610 611 630 655 656 657 658 696 697 698 699).map { |c| "#{c}abcdefghijklmnopqrstu"}.join(':'), alternate_script: false) do |record, accumulator|
  accumulator.reject! { |v| v == 'nomesh' }
  if record['999'] && record['999']['m'] == 'LANE-MED'
    arr = []
    extract_marc('655a').call(record, arr, nil)
    accumulator.reject! { |v| arr.include? v }
  end
end
to_field "vern_subject_other_search", extract_marc(%w(600 610 611 630 655 656 657 658 696 697 698 699).map { |c| "#{c}abcdefghijklmnopqrstu"}.join(':'), alternate_script: :only)
to_field "subject_other_subvy_search", extract_marc(%w(600 610 611 630 650 651 654 655 656 657 658 690 691 696 697 698 699).map { |c| "#{c}vy"}.join(':'), alternate_script: false)
to_field "vern_subject_other_subvy_search", extract_marc(%w(600 610 611 630 650 651 654 655 656 657 658 690 691 696 697 698 699).map { |c| "#{c}vy"}.join(':'), alternate_script: :only)
to_field "subject_all_search", extract_marc(%w(600 610 611 630 648 650 651 652 653 654 655 656 657 658 662 690 691 696 697 698 699).map { |c| "#{c}#{ALPHABET}" }.join(':'), alternate_script: false)
to_field "vern_subject_all_search", extract_marc(%w(600 610 611 630 648 650 651 652 653 654 655 656 657 658 662 690 691 696 697 698 699).map { |c| "#{c}#{ALPHABET}"}.join(':'), alternate_script: :only)

# Subject Facet Fields
to_field "topic_facet", extract_marc("600abcdq:600t:610ab:610t:630a:630t:650a", alternate_script: false, trim_punctuation: true) do |record, accumulator|
  accumulator.reject! { |v| v == 'nomesh' }
  accumulator.map! { |v| v.gsub(/([\p{L}\p{N}]{4}|[A-Za-z]{3}|\))[\\,;:\.]\.?$/, '\1')}
  accumulator.map!(&method(:clean_facet_punctuation))
end
to_field "geographic_facet", extract_marc("651a:" + (600...699).map { |x| "#{x}z" }.join(':'), alternate_script: false) do |record, accumulator|
  accumulator.map! { |v| v.gsub(/([A-Za-z0-9]{2}|\))[\\,;\.]\.?$/, '\1') }
end
to_field "era_facet", extract_marc("650y:651y", alternate_script: false, trim_punctuation: true) do |record, accumulator|
  accumulator.map!(&method(:clean_facet_punctuation))
end

def clean_facet_punctuation(value)
  new_value = value.gsub(/^[%\\*]/, ''). # begins with percent sign or asterisk
                    gsub(/\({2,}+/, '('). # two or more open parentheses
                    gsub(/\){2,}+/, ')'). # two or more close parentheses
                    gsub(/!{2,}+/, '!'). #  two or more exlamation points
                    gsub(/\s+/, ' ') # one or more spaces

  new_value[/(?<valid>\(\g<valid>*\)|[^()])+/x] # remove unmatched parentheses
end

# # Publication Fields
# pub_search = custom, getPublication
# vern_pub_search = custom, getLinkedField(260ab:264ab)
# pub_country = 008[15-17]:008[15-16], country_map.properties, first
# # publication dates
# # deprecated
# pub_date = custom, getPubDate
# pub_date_sort = custom, getPubDateSort
# pub_year_tisim = custom, getPubDateSliderVals
def marc_008_date(byte6values, byte_range, u_replacement)
  lambda do |record, accumulator|
    Traject::MarcExtractor.new('008').collect_matching_lines(record) do |field, spec, extractor|
      if byte6values.include? field.value[6]
        year = field.value[byte_range]
        next unless year =~ /(\d{4}|\d{3}u)/
        year.gsub!(/u$/, u_replacement)
        next unless (500..(Time.now.year + 10)).include? year.to_i
        accumulator << year
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
to_field 'other_year_isi', marc_008_date(%w[a b f g h j l n o v w x y z | $], 7..10, '0')
# # from 008 date 2
to_field 'ending_year_isi', marc_008_date(%w[d m], 11..14, '9')
to_field 'latest_year_isi', marc_008_date(%w[i k], 11..14, '9')
to_field 'latest_poss_year_isi', marc_008_date(%w[q], 11..14, '9')
to_field 'production_year_isi', marc_008_date(%w[p], 11..14, '9')
to_field 'original_year_isi', marc_008_date(%w[r], 11..14, '9')
to_field 'copyright_year_isi', marc_008_date(%w[t], 11..14, '9')
# # from 260c
# imprint_display = custom, getImprint
#
# # Date field for new items feed
to_field "date_cataloged", extract_marc("916b") do |record, accumulator|
  accumulator.reject! { |v| v =~ /NEVER/i }

  accumulator.map! do |v|
    "#{v[0..3]}-#{v[4..5]}-#{v[6..7]}T00:00:00Z"
  end
end

#
# language = custom, getLanguages, language_map.properties
#
# # old format field, left for continuity in UI URLs for old formats
# format = custom, getOldFormats
# format_main_ssim = custom, getMainFormats
# format_physical_ssim = custom, getPhysicalFormats
# genre_ssim = custom, getAllGenres
#
# db_az_subject = custom, getDbAZSubjects, db_subjects_map.properties

to_field "physical", extract_marc("300abcefg", alternate_script: false)
to_field "vern_physical", extract_marc("300abcefg", alternate_script: :only)

to_field "toc_search", extract_marc("905art:505art", alternate_script: false)
to_field "vern_toc_search", extract_marc("505art", alternate_script: :only)
to_field "context_search", extract_marc("518a", alternate_script: false)
to_field "vern_context_search", extract_marc("518a", alternate_script: :only)
to_field "summary_search", extract_marc("920ab:520ab", alternate_script: false)
to_field "vern_summary_search", extract_marc("520ab", alternate_script: :only)
to_field "award_search", extract_marc("986a:586a", alternate_script: false)

#
# # URL Fields
# url_fulltext = custom, getFullTextUrls
# url_suppl = custom, getSupplUrls
# url_sfx = 956u, (pattern_map.sfx)
# url_restricted = custom, getRestrictedUrls
#
# # Standard Number Fields
# isbn_search = custom, getUserISBNs
# # Added fields for searching based upon list from Kay Teel in JIRA ticket INDEX-142
# TODO: figure out what "(pattern_map.issn)" is intending to do, add the behavior in traject and test it
to_field 'issn_search', extract_marc('022a:022l:022m:022y:022z:400x:410x:411x:440x:490x:510x:700x:710x:711x:730x:760x:762x:765x:767x:770x:771x:772x:773x:774x:775x:776x:777x:778x:779x:780x:781x:782x:783x:784x:785x:786x:787x:788x:789x:800x:810x:811x:830x')
# issn_search = 022a:022l:022m:022y:022z:400x:410x:411x:440x:490x:510x:700x:710x:711x:730x:760x:762x:765x:767x:770x:771x:772x:773x:774x:775x:776x:777x:778x:779x:780x:781x:782x:783x:784x:785x:786x:787x:788x:789x:800x:810x:811x:830x, (pattern_map.issn)

def extract_isbn(value)
  isbn10_pattern = /^\d{9}[\dX].*/
  isbn13_pattern = /^(978|9)\d{9}[\dX].*/
  isbn13_any = /^\d{12}[\dX].*/

  if value =~ isbn13_pattern
    value[0, 13]
  elsif value =~ isbn10_pattern && value !~ isbn13_any
    value[0, 10]
  end
end

to_field 'isbn_display', extract_marc('020a') do |_record, accumulator|
  accumulator.map!(&method(:extract_isbn))
end

to_field 'isbn_display' do |record, accumulator, context|
  next unless context.output_hash['isbn_display'].nil?

  marc020z = Traject::MarcExtractor.new('020z').extract(record)
  accumulator.concat marc020z.map(&method(:extract_isbn))
end

  if marc020a.any?
    accumulator.concat extract_isbn(marc020a)
  elsif marc020z.any?
    accumulator.concat extract_isbn(marc020z)
  end
end

# issn_display = custom, getISSNs

to_field 'lccn', extract_marc('010a:010z', first: true, trim_punctuation: true) do |record, accumulator|
  lccn_pattern = /^(?:([ a-z]{2}\d{10})|([ a-z]{3}\d{8})|((\d{11}|\d{10}|\d{8})).*)$/
  accumulator.map! do |value|
    value.scan(lccn_pattern).flatten.compact.first
  end
end
# lccn = 010a:010z, (pattern_map.lccn), first

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
# callnum_facet_hsim = custom, getCallNumHierarchVals(|, callnumber_map)
# callnum_search = custom, getLocalCallNums
# shelfkey = custom, getShelfkeys
# reverse_shelfkey = custom, getReverseShelfkeys
#
# # Location facet
# location_facet = custom, getLocationFacet
#
# # Stanford student work facet
# stanford_work_facet_hsim = custom, getStanfordWorkFacet
# stanford_dept_sim = custom, getStanfordDeptFacet
#
# # Item Info Fields (from 999 that aren't call number)
# barcode_search = 999i
# preferred_barcode = custom, getPreferredItemBarcode
# access_facet = custom, getAccessMethods
# building_facet = custom, getBuildings, library_map.properties
# item_display = customDeleteRecordIfFieldEmpty, getItemDisplay
#

to_field 'on_order_library_ssim', extract_marc('596', translation_map: 'library_on_order_map')
# mhld_display = custom, getMhldDisplay
# bookplates_display = custom, getBookplatesDisplay
# fund_facet = custom, getFundFacet
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
#
# # INDEX-142 NOTE 3: Lane Medical adds (Print) or (Digital) descriptors to their ISSNs
# # so need to account for it in the pattern match below
# pattern_map.issn.pattern_0 = ^(\\d{4}-\\d{3}[X\\d]\\D*)$=>$1
#
# pattern_map.lccn.pattern_0 = ^(([ a-z]{3}\\d{8})|([ a-z]{2}\\d{10})) ?|( /.*)?$=>$1
#
# pattern_map.sfx.pattern_0 = ^(http://library.stanford.edu/sfx\\?(.+))=>$1
# pattern_map.sfx.pattern_1 = ^(http://caslon.stanford.edu:3210/sfxlcl3\\?(.+))=>$1
