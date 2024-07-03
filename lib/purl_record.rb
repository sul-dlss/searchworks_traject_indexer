# frozen_string_literal: true

require 'http'
require 'active_support' # some transitive dependencies don't require active_support this first, as they must in Rails 7
require 'active_support/core_ext/module/delegation'
require 'mods_display'
require 'dor/rights_auth'

class PurlRecord
  attr_reader :druid, :purl_url

  def initialize(druid, purl_url: 'https://purl.stanford.edu')
    @druid = druid
    @purl_url = purl_url
  end

  def searchworks_id
    catkey.nil? ? druid : catkey
  end

  def druid_tree
    druid.match(/(..)(...)(..)(....)/).captures.join('/')
  end

  def public_xml
    @public_xml ||= PublicXmlRecord.fetch(druid, purl_url:)
  end

  def public_cocina
    @public_cocina ||= PublicCocinaRecord.fetch(druid, purl_url:)
  end

  def public_xml?
    public_xml.present?
  end

  def public_cocina?
    public_cocina.present?
  end

  # Ensure all objects, even those missing public xml/cocina have a (nil) catkey and a label
  delegate :catkey, :label, to: :public_xml, allow_nil: true

  delegate :mods, :rights, :rights_xml, :collection?, :public?, :stanford_only?,
           :thumb, :dor_content_type, :dor_resource_content_type, :dor_file_mimetype,
           :dor_resource_count, :dor_read_rights, :collections, :constituents,
           :stanford_mods, :mods_display,
           :public_xml_doc, to: :public_xml

  delegate :cocina_access, :cocina_structural, :cocina_description, :cocina_titles,
           :created, :modified, :public_cocina_doc, :content_type, :files, to: :public_cocina
end
