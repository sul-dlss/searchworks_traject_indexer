# frozen_string_literal: true

require 'active_support' # some transitive dependencies don't require active_support this first, as they must in Rails 7
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/module/delegation'

class PurlRecord
  attr_reader :druid, :purl_url

  def initialize(druid, purl_url: 'https://purl.stanford.edu')
    @druid = druid
    @purl_url = purl_url
  end

  def searchworks_id
    catkey || druid
  end

  def druid_tree
    druid.match(/(..)(...)(..)(....)/).captures.join('/')
  end

  def public_xml
    @public_xml ||= PublicXmlRecord.fetch(druid, purl_url:)
  end

  def public_cocina
    @public_cocina ||= CocinaDisplay::CocinaRecord.fetch(druid, purl_url:)
  end

  def public_meta_json
    @public_meta_json ||= PublicMetaJsonRecord.fetch(druid, purl_url:)
  end

  def public_xml?
    public_xml.present?
  end

  def public_cocina?
    public_cocina.present?
  end

  def public_meta_json?
    public_meta_json.present?
  end

  # Fetch full metadata for any collections this object belongs to
  # @return [Array<PurlRecord>]
  def collections
    @collections ||= public_cocina.containing_collections.map do |druid|
      PurlRecord.new(druid, purl_url:)
    end
  end

  # Fetch full metadata for any virtual objects this object belongs to
  # @return [Array<PurlRecord>]
  def parents
    @parents ||= public_cocina.virtual_object_parents.map do |druid|
      PurlRecord.new(druid, purl_url:)
    end
  end

  # Fetch full metadata for each member object, if this is a virtual object
  # @return [Array<PurlRecord>]
  def members
    @members ||= public_cocina.virtual_object_members.map do |druid|
      PurlRecord.new(druid, purl_url:)
    end
  end

  # IIIF ID used to construct a thumbnail image URL for this object
  # @example "ts786ny5936_1%2FPC0170_s1_E_0204.jp2"
  # @return [String, nil]
  def thumbnail_file_id
    thumbnail_file = public_cocina.thumbnail_file

    # If no thumbnail (e.g. virtual object), use first avail. member thumbnail
    members.each do |member|
      thumbnail_file = member.public_cocina.thumbnail_file
      break if thumbnail_file.present?
    end if thumbnail_file.nil?

    thumbnail_file&.iiif_id
  end

  # Ensure all objects, even those missing public xml/cocina have a (nil) catkey and a label
  delegate :catkey, to: :public_cocina, allow_nil: true
  delegate :label, to: :public_cocina, allow_nil: true

  delegate :mods, :stanford_mods, :mods_display, :public_xml_doc, to: :public_xml

  delegate :collection?, :content_type, :files, :filesets, :cocina_doc, :world_access?,
           :modified_time, :created_time, :searchworks_url, :iiif_manifest_url,
           :virtual_object?, :preferred_citation, :license, to: :public_cocina

  delegate :released_to_earthworks?, :released_to_searchworks?, to: :public_meta_json
end
