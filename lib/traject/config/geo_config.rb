$LOAD_PATH << File.expand_path('../..', __dir__)

require 'traject'
require 'stanford-mods'
require 'sdr_stuff'
require 'kafka'
require 'traject/readers/kafka_purl_fetcher_reader'
require 'traject/writers/solr_better_json_writer'
require 'utils'
require 'honeybadger'
require 'digest/md5'
class GeoAuthorities
  def self.formats
    {
      'application/x-esri-shapefile' => 'Shapefile',
      'Geodatabase' => 'Geodatabase'
    }
  end

  def self.subjects
    {
      'farming' => 'Farming',
      'biota' => 'Biology and Ecology',
      'climatologyMeteorologyAtmosphere' => 'Climatology, Meteorology and Atmosphere',
      'boundaries' => 'Boundaries',
      'elevation' => 'Elevation',
      'environment' => 'Environment',
      'geoscientificInformation' => 'Geoscientific Information',
      'health' => 'Health',
      'imageryBaseMapsEarthCover' => 'Imagery and Base Maps',
      'intelligenceMilitary' => 'Military',
      'inlandWaters' => 'Inland Waters',
      'location' => 'Location',
      'oceans' => 'Oceans',
      'planningCadastre' => 'Planning and Cadastral',
      'structure' => 'Structure',
      'transportation' => 'Transportation',
      'utilitiesCommunication' => 'Utilities and Communication',
      'society' => 'Society',
      'economy' => 'Economy'
    }
  end

  def self.geometry_types
    {
      'esriGeometryPoint' => 'Point',
      'esriGeometryPolygon' => 'Polygon',
      'esriGeometryPolyline' => 'Line'
    }
  end
end

Utils.logger = logger
extend Traject::SolrBetterJsonWriter::IndexerPatch

def log_skip(context)
  writer.put(context)
end

$druid_title_cache = {}

indexer = self

settings do
  provide 'writer_class_name', 'Traject::SolrBetterJsonWriter'
  provide 'solr.url', ENV['SOLR_URL']
  provide 'solr.version', ENV['SOLR_VERSION']
  provide 'purl_fetcher.skip_catkey', false
  provide 'processing_thread_pool', ENV['NUM_THREADS']
  provide 'solr_better_json_writer.debounce_timeout', 5
  if ENV['KAFKA_TOPIC']
    provide "reader_class_name", "Traject::KafkaPurlFetcherReader"
    kafka = Kafka.new(ENV.fetch('KAFKA', 'localhost:9092').split(','))
    consumer = kafka.consumer(group_id: ENV.fetch('KAFKA_CONSUMER_GROUP_ID', "traject_#{ENV['KAFKA_TOPIC']}"), fetcher_max_queue_size: 15)
    consumer.subscribe(ENV['KAFKA_TOPIC'])
    provide 'kafka.consumer', consumer
  end

  provide 'purl_fetcher.target', ENV.fetch('PURL_FETCHER_TARGET', 'Earthworks')
  provide 'purl.url', ENV.fetch('PURL_URL', 'https://purl.stanford.edu')
  provide 'solr_writer.commit_on_close', true
  if defined?(JRUBY_VERSION)
    require 'traject/manticore_http_client'
    provide 'solr_json_writer.http_client', Traject::ManticoreHttpClient.new
  else
    provide 'solr_json_writer.http_client', HTTPClient.new.tap { |x| x.receive_timeout = 600 }
  end
  provide 'solr_json_writer.skippable_exceptions', [HTTPClient::TimeoutError, StandardError]

  provide 'mapping_rescue', (lambda do |context, e|
    Honeybadger.notify(e, context: { record: context.record_inspect, index_step: context.index_step.inspect })

    indexer.send(:default_mapping_rescue).call(context, e)
  end)
end

def stanford_mods(method, *args, default: nil)
  lambda do |resource, accumulator, _context|
    data = Array(resource.stanford_mods.public_send(method, *args))

    data.each do |v|
      accumulator << v
    end

    accumulator << default if data.empty?
  end
end

def mods_xpath(xpath)
  lambda do |resource, accumulator, _context|
    accumulator << resource.mods.xpath(xpath, mods: 'http://www.loc.gov/mods/v3', dc: 'http://purl.org/dc/elements/1.1/')
  end
end

def mods_display(method, *args, default: nil)
  lambda do |resource, accumulator, _context|
    data = Array(resource.mods_display.public_send(method, *args))

    data.each do |v|
      v.values.each do |v2|
        accumulator << v2.to_s
      end
    end

    accumulator << default if data.empty?
  end
end

module Constants
  GEOWEBSERVICES = {
    'Public': 'https://geowebservices.stanford.edu/geoserver',
    'Restricted': 'https://geowebservices-restricted.stanford.edu/geoserver'
  }
end

each_record do |record, context|
  context.clipboard[:benchmark_start_time] = Time.now
end

##
# Skip records that have a delete field
each_record do |record, context|
  if record.is_a?(Hash) && record[:delete]
    context.output_hash['id'] = [record[:id].sub('druid:', '')]
    context.skip!('Delete')
  end
end

to_field 'dc_identifier_s' do |record, accumulator|
  accumulator << "http://purl.stanford.edu/#{record.druid}"
end

each_record do |record, context|
  context.skip!('This item is in processing or does not exist') unless record.public_xml?
  context.skip!(
    "This content type: #{record.dor_content_type} is not supported"
  ) unless (%w[image map book geo file].include?(record.dor_content_type) || record.is_collection)
end

to_field 'dc_title_s', stanford_mods(:sw_short_title, default: '[Untitled]')
to_field 'dc_description_s' do |record, accumulator|
  description = []
  record.mods_display.abstract.map do |abstract|
    description << abstract.values
  end
  record.mods_display.note.map do |note|
    description << note.values
  end
  accumulator << description.join(' ')
end
to_field 'dc_rights_s' do |record, accumulator|
  if record.public?
    accumulator << 'Public'
  elsif record.stanford_only?
    accumulator << 'Restricted'
  end
end

to_field 'layer_geom_type_s', mods_xpath('mods:extension[@displayLabel="geo"]//dc:type') do |record, accumulator|
  data = accumulator.flatten.select { |v| v.text =~ /#/ }.map { |v| v.text.split('#', 2).last }.slice(0..0)
  data.map! { |v| GeoAuthorities.geometry_types.fetch(v, v) }
  accumulator.replace(data)
end

to_field 'layer_geom_type_s' do |record, accumulator, context|
  next if context.output_hash['layer_geom_type_s'] && !context.output_hash['layer_geom_type_s'].empty?

  accumulator << 'Image' if %w[image map book].include?(record.dor_content_type)
  accumulator << 'Collection' if record.is_collection
end

to_field 'layer_modified_dt' do |record, accumulator|
  accumulator << record.public_xml_doc.root.attr('published')
end

to_field 'dct_issued_s', mods_xpath('mods:originInfo/mods:dateIssued') do |record, accumulator|
  data = accumulator.flatten.map(&:text).slice(0..0)
  accumulator.replace(data)
end

to_field 'dc_type_s', mods_xpath('mods:extension[@displayLabel="geo"]//dc:type')  do |record, accumulator|
  data = accumulator.flatten.map(&:text).uniq.map { |v| v.split('#', 2).first }.slice(0..0)
  accumulator.replace(data)
end

to_field 'dc_type_s' do |record, accumulator, context|
  next if context.output_hash['dc_type_s'] && !context.output_hash['dc_type_s'].empty?

  accumulator << 'Image' if %w[image map book].include?(record.dor_content_type)
end

to_field 'dc_format_s', mods_xpath('mods:extension[@displayLabel="geo"]//dc:format') do |record, accumulator|
  data = accumulator.flatten.map(&:text).select { |v| v =~ /format=/ }.map { |v| v.split('format=', 2).last }.slice(0..0)
  if (data.present?)
    accumulator.replace(data.uniq.map { |v| GeoAuthorities.formats.fetch(v, v) })
  else
    accumulator.uniq!
    accumulator.flatten!
    accumulator.map!(&:text)
  end
end

to_field 'dc_format_s' do |record, accumulator, context|
  next if context.output_hash['dc_format_s'] && !context.output_hash['dc_format_s'].empty?

  accumulator << 'JPEG 2000' if %w[image map book].include?(record.dor_content_type)
end

to_field 'dc_language_s', stanford_mods(:sw_language_facet), first_only
to_field 'dc_subject_sm', stanford_mods(:subject_other_search) do |record, accumulator|
  accumulator.map! { |val| val.sub(/[\\,;]$/, '').strip if val }
end
to_field 'dc_subject_sm', mods_xpath('mods:subject/mods:topic') do |record, accumulator|
  accumulator.flatten!
  accumulator.map! do |val|
    if val.attr('authority') =~ /ISO19115topicCategory/i
      GeoAuthorities.subjects[val.attr('valueURI')] || val.text || val.attr('valueURI')
    else
      val.text
    end
  end
  accumulator.uniq!
  accumulator.compact!
end

to_field 'dct_spatial_sm', stanford_mods(:geographic_facet)
to_field 'dct_temporal_sm', stanford_mods(:era_facet) do |_record, accumulator|
  accumulator.uniq!
end

to_field 'dc_publisher_s',
         stanford_mods(:term_values, %I[origin_info publisher]),
         first_only
to_field 'dc_creator_sm', stanford_mods(:sw_person_authors) do |_record, accumulator|
  accumulator.map! { |str| trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff(str) }
end

to_field 'dc_creator_sm', stanford_mods(:sw_corporate_authors) do |_record, accumulator|
  accumulator.map! { |str| trim_punctuation_when_preceded_by_two_word_characters_or_some_other_stuff(str) }
end

to_field 'layer_availability_score_f', literal(1.0)
to_field 'geoblacklight_version', literal('1.0')
to_field 'dct_references_s' do |record, accumulator, context|
  references = {
    'http://schema.org/url' => "https://purl.stanford.edu/#{record.druid}",
    'http://www.loc.gov/mods/v3' => "https://purl.stanford.edu/#{record.druid}.mods",
  }
  case record.dor_content_type
  when 'file'
    references.merge!({
      'https://oembed.com' => "https://purl.stanford.edu/embed.json?&hide_title=true&url=https://purl.stanford.edu/#{record.druid}",
    })
  when 'image', 'map', 'book'
    references.merge!({
      'https://oembed.com' => "https://purl.stanford.edu/embed.json?&hide_title=true&url=https://purl.stanford.edu/#{record.druid}",
      'http://iiif.io/api/presentation#manifest' => "https://purl.stanford.edu/#{record.druid}/iiif/manifest"
    })
  when 'geo'
    formats = context.output_hash['dc_format_s'] || []

    references.merge!({
      'http://schema.org/downloadUrl' =>  "https://stacks.stanford.edu/file/druid:#{record.druid}/data.zip",
      'http://www.opengis.net/def/serviceType/ogc/wms' => "#{Constants::GEOWEBSERVICES[context.output_hash['dc_rights_s'][0].to_sym]}/wms",
      'http://www.isotc211.org/schemas/2005/gmd/' => "https://raw.githubusercontent.com/OpenGeoMetadata/edu.stanford.purl/master/#{record.druid_tree}/iso19139.xml",
    })

    if formats.include?('Shapefile')
      references.merge!({
        'http://www.opengis.net/def/serviceType/ogc/wfs' => "#{Constants::GEOWEBSERVICES[context.output_hash['dc_rights_s'][0].to_sym]}/wfs",
      })
    elsif formats.include?('GeoTIFF') || formats.include?('ArcGRID')
      references.merge!({
        'http://www.opengis.net/def/serviceType/ogc/wcs' => "#{Constants::GEOWEBSERVICES[context.output_hash['dc_rights_s'][0].to_sym]}/wcs",
      })
    end

    index_map = record.public_xml_doc.xpath('//file[@id="index_map.json"]').length > 0

    if index_map
      references.merge!({
        'https://openindexmaps.org' => "https://stacks.stanford.edu/file/druid:#{druid}/index_map.json"
      })
    end
  end
  accumulator << references.to_json
end
to_field 'solr_geom', stanford_mods(:geo_extensions_as_envelope)
to_field 'solr_geom', stanford_mods(:coordinates_as_envelope)
to_field 'layer_slug_s' do |record, accumulator|
  accumulator << "stanford-#{record.druid}"
end
to_field 'layer_id_s' do |record, accumulator|
  accumulator << "druid:#{record.druid}" unless record.is_collection
end

to_field 'hashed_id_ssi' do |_record, accumulator, context|
  next unless context.output_hash['layer_slug_s']

  accumulator << Digest::MD5.hexdigest(context.output_hash['layer_slug_s'].first)
end

to_field 'dct_provenance_s', literal('Stanford')
to_field 'stanford_rights_metadata_s' do |record, accumulator|
  accumulator << record.rights_xml
end

to_field 'solr_year_i' do |record, accumulator|
  subject_year = record.stanford_mods.year_int(record.stanford_mods.subject.temporal)

  accumulator << subject_year if subject_year
  accumulator << record.stanford_mods.pub_year_int if accumulator.empty?
end

to_field 'dc_source_sm' do |record, accumulator|
  next unless record.dor_content_type == 'geo'
  next unless record.collections && record.collections.any?

  record.collections.uniq.each do |collection|
    accumulator << "stanford-#{collection.druid}"
  end
end

to_field 'dct_isPartOf_sm', mods_xpath('mods:relatedItem[@type="host"]/mods:titleInfo/mods:title') do |record, accumulator|
  accumulator.flatten!
  accumulator.map!(&:text)
  accumulator.uniq!
end

each_record do |record, context|
  $druid_title_cache[record.druid] = record.label if record.is_collection
end

each_record do |record, context|
  context.output_hash.select { |k, _v| k =~ /_struct$/ }.each do |k, v|
    context.output_hash[k] = Array(v).map { |x| JSON.generate(x) }
  end
end

each_record do |_record, context|
  # Make sure that this field is single valued. GeoBlacklight at the moment only
  # supports single valued srpt
  if context.output_hash['solr_geom'].present?
    context.output_hash['solr_geom'] = context.output_hash['solr_geom'].first
  else
    context.skip!(
      "No ENVELOPE available for #{context.output_hash['id']}"
    )
  end
end

each_record do |record, context|
  t0 = context.clipboard[:benchmark_start_time]
  t1 = Time.now

  logger.debug('geo_config.rb') { "Processed #{context.output_hash['id']} (#{t1 - t0}s)" }
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
