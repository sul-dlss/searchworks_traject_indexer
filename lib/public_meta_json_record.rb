# frozen_string_literal: true

require 'http'

class PublicMetaJsonRecord
  attr_reader :public_meta_json_doc, :druid, :purl_url

  def self.fetch(druid, purl_url: 'https://purl.stanford.edu')
    response = HTTP.get("#{purl_url}/#{druid}.meta_json")
    new(druid, response.body, purl_url:) if response.status.ok?
  end

  def initialize(druid, public_meta_json, purl_url: 'https://purl.stanford.edu')
    @druid = druid
    @purl_url = purl_url
    @public_meta_json_doc = JSON.parse(public_meta_json)
  end

  def released_to_earthworks?
    public_meta_json_doc.fetch('earthworks')
  end

  def released_to_searchworks?
    public_meta_json_doc.fetch('searchworks')
  end
end
