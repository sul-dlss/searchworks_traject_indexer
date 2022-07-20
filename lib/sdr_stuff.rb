require 'http'
require 'active_support' # some transitive dependencies don't require this first, as they must in Rails 7
require 'mods_display'
require 'dor/rights_auth'

class SdrReader
  attr_reader :input_stream

  # @param input_stream [File|IO]
  # @param settings [Traject::Indexer::Settings]
  def initialize(input_stream, settings)
    @settings = Traject::Indexer::Settings.new settings
    @input_stream = input_stream
  end

  def each(*args, &block)
    input_stream.each_line do |druid|
      yield PublicXmlRecord.new(druid, purl_url: @settings['purl.url'])
    end
  end
end

class PublicXmlRecord
  attr_reader :druid

  def self.fetch(url)
    if defined?(JRUBY_VERSION)
      response = Manticore.get(url)
      response.body if response.code == 200
    else
      response = HTTP.get(url)
      response.body if response.status.ok?
    end
  end

  attr_reader :purl_url

  def initialize(druid, purl_url: 'https://purl.stanford.edu')
    @druid = druid
    @purl_url = purl_url
  end

  def searchworks_id
    catkey.nil? ? druid : catkey
  end

  # @return catkey value from the DOR identity_metadata, or nil if there is no catkey
  def catkey
    get_value(public_xml_doc.xpath("/publicObject/identityMetadata/otherId[@name='catkey']")).presence
  end

  # @return objectLabel value from the DOR identity_metadata, or nil if there is no barcode
  def label
    get_value(public_xml_doc.xpath('/publicObject/identityMetadata/objectLabel'))
  end

  def get_value(node)
    (node && node.first) ? node.first.content : nil
  end

  def stanford_mods
    @smods_rec ||= Stanford::Mods::Record.new.tap do |smods_rec|
      smods_rec.from_str(mods.to_s)
    end
  end

  def mods_display
    @mods_display ||= ModsDisplay::HTML.new(stanford_mods)
  end

  def public_xml?
    !!public_xml
  end

  def public_xml
    @public_xml ||= self.class.fetch("#{purl_url}/#{druid}.xml")
  end

  def public_xml_doc
    @public_xml_doc ||= Nokogiri::XML(public_xml)
  end

  def mods
    @mods ||= if public_xml_doc.xpath('/publicObject/mods:mods', mods: 'http://www.loc.gov/mods/v3').any?
      public_xml_doc.xpath('/publicObject/mods:mods', mods: 'http://www.loc.gov/mods/v3').first
    else
      Nokogiri::XML self.class.fetch("#{purl_url}/#{druid}.mods")
    end
  end

  def rights
    @rights ||= ::Dor::RightsAuth.parse(rights_xml)
  end

  def public?
    rights.world_rights.first
  end

  def stanford_only?
    rights.stanford_only_rights.first
  end

  def rights_xml
    @rights_xml ||= public_xml_doc.xpath('//rightsMetadata').to_s
  end

  # @return true if the identityMetadata has <objectType>collection</objectType>, false otherwise
  def is_collection
    object_type_nodes = public_xml_doc.xpath('//objectType')
    object_type_nodes.find_index { |n| %w(collection set).include? n.text.downcase }
  end

  # value is used to tell SearchWorks UI app of specific display needs for objects
  # this comes from the <thumb> element in publicXML or the first image found (as parsed by discovery-indexer)
  # @return [String] filename or nil if none found
  def thumb
    return if is_collection
    encoded_thumb if %w(book image manuscript map webarchive-seed).include?(dor_content_type)
  end

  # the value of the type attribute for a DOR object's contentMetadata
  #  more info about these values is here:
  #    https://consul.stanford.edu/display/chimera/DOR+content+types%2C+resource+types+and+interpretive+metadata
  #    https://consul.stanford.edu/display/chimera/Summary+of+Content+Types%2C+Resource+Types+and+their+behaviors
  # @return [String]
  def dor_content_type
    public_xml_doc.xpath('//contentMetadata/@type').text
  end

  # the values of the type attribute for a DOR object's contentMetadata/resource elements
  # @return [Array<String>]
  def dor_resource_content_type
    public_xml_doc.xpath('//contentMetadata/resource/@type').map(&:text)
  end

  # the values of the mimetype attribute for a DOR object's contentMetadata/resource/* elements
  # @return [Array<String>]
  def dor_file_mimetype
    public_xml_doc.xpath('//contentMetadata/resource/*/@mimetype').map(&:text)
  end

  # the count of a DOR object's contentMetadata/resource elements
  # @return [Integer]
  def dor_resource_count
    public_xml_doc.xpath('//contentMetadata/resource').count
  end

  # the element names for a DOR object's rightsMetadata/access/machine/*
  # where the access type is "read"
  # @return [Array<String>]
  def dor_read_rights
    public_xml_doc.xpath('//rightsMetadata/access[@type="read"]/machine/*').map(&:name)
  end

  # the thumbnail in publicXML, falling back to the first image if no thumb node is found
   # @return [String] thumb filename with druid prepended, e.g. oo000oo0001/filename withspace.jp2
   def parse_thumb
     unless public_xml_doc.nil?
       thumb = public_xml_doc.xpath('//thumb')
       # first try and parse what is in the thumb node of publicXML, but fallback to the first image if needed
       if thumb.size == 1
         thumb.first.content
       elsif thumb.size == 0 && parse_sw_image_ids.size > 0
         parse_sw_image_ids.first
       else
         nil
       end
     end
   end

   # the druid and id attribute of resource/file and objectId and fileId of the
      # resource/externalFile elements that match the image, page, or thumb resource type, including extension
      # Also, prepends the corresponding druid and / specifically for Searchworks use
      # @return [Array<String>] filenames
      def parse_sw_image_ids
        public_xml_doc.xpath('//resource[@type="page" or @type="image" or @type="thumb"]').map do |node|
          node.xpath('./file[@mimetype="image/jp2"]/@id').map{ |x| "#{@druid.gsub('druid:','')}/" + x } << node.xpath('./externalFile[@mimetype="image/jp2"]').map do |y|
            "#{y.attributes['objectId'].text.split(':').last}" + "/" + "#{y.attributes['fileId']}"
          end
        end.flatten
      end

   def collections
     @collections ||= predicate_druids('isMemberOfCollection').map do |druid|
       PublicXmlRecord.new(druid, purl_url: purl_url)
     end
   end

   def constituents
     @constituents ||= predicate_druids('isConstituentOf').map do |druid|
       PublicXmlRecord.new(druid, purl_url: purl_url)
     end
   end

   # the thumbnail in publicXML properly URI encoded, including the slash separator
   # @return [String] thumb filename with druid prepended, e.g. oo000oo0001%2Ffilename%20withspace.jp2
  def encoded_thumb
    thumb=parse_thumb
    return unless thumb
    thumb_druid=thumb.split('/').first # the druid (before the first slash)
    thumb_filename=thumb.split(/[a-zA-Z]{2}[0-9]{3}[a-zA-Z]{2}[0-9]{4}[\/]/).last # everything after the druid
    "#{thumb_druid}%2F#{ERB::Util.url_encode(thumb_filename)}"
  end

  # get the druids from predicate relationships in rels-ext from public_xml
  # @return [Array<String>, nil] the druids (e.g. ww123yy1234) from the rdf:resource of the predicate relationships, or nil if none
  def predicate_druids(predicate, predicate_ns = 'info:fedora/fedora-system:def/relations-external#')
    ns_hash = { 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'pred_ns' => predicate_ns }
    xpth = "/publicObject/rdf:RDF/rdf:Description/pred_ns:#{predicate}/@rdf:resource"
    pred_nodes = public_xml_doc.xpath(xpth, ns_hash)
    pred_nodes.reject { |n| n.value.empty? }.map do |n|
      n.value.split('druid:').last
    end
  end

  def druid_tree
    druid.match(/(..)(...)(..)(....)/).captures.join('/')
  end
end
