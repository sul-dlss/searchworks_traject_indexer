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

  def public_xml?
    !!public_xml
  end

  def public_xml
    @public_xml ||= PublicXmlRecord.fetch(purl_url, druid)
  end

  delegate :mods, :rights, :public?, :stanford_only?, :rights_xml, :collection?,
           :thumb, :dor_content_type, :dor_resource_content_type, :dor_file_mimetype,
           :dor_resource_count, :dor_read_rights, :collections, :constituents,
           :catkey, :label, :stanford_mods, :mods_display,
           :public_xml_doc, to: :public_xml

  def druid_tree
    druid.match(/(..)(...)(..)(....)/).captures.join('/')
  end
end
