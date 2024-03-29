# frozen_string_literal: true

require 'http'

class PublicCocinaRecord
  attr_reader :druid, :purl_url

  def self.fetch(url)
    response = HTTP.get(url)
    response.body if response.status.ok?
  end

  def initialize(druid, purl_url: 'https://purl.stanford.edu')
    @druid = druid
    @purl_url = purl_url
  end

  def public_cocina?
    !!public_cocina
  end

  def public_cocina
    @public_cocina ||= self.class.fetch("#{purl_url}/#{druid}.json")
  end

  def public_cocina_doc
    @public_cocina_doc ||= JSON.parse(public_cocina)
  end
end
