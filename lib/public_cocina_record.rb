# frozen_string_literal: true

require 'http'

class PublicCocinaRecord
  attr_reader :public_cocina_doc, :cocina_display, :druid, :purl_url

  def self.fetch(druid, purl_url: 'https://purl.stanford.edu')
    response = HTTP.get("#{purl_url}/#{druid}.json")
    new(druid, response.body, purl_url:) if response.status.ok?
  end

  def initialize(druid, public_cocina, purl_url: 'https://purl.stanford.edu')
    @druid = druid
    @purl_url = purl_url
    @public_cocina_doc = JSON.parse(public_cocina)
    @cocina_display = CocinaDisplay::CocinaRecord.new(@public_cocina_doc)
  end

  def label
    public_cocina_doc['label']
  end

  def cocina_access
    @cocina_access ||= public_cocina_doc['access']
  end

  def cocina_structural
    @cocina_structural ||= public_cocina_doc['structural']
  end

  def cocina_description
    @cocina_description ||= public_cocina_doc['description']
  end

  def cocina_titles(type: :main)
    case type
    when :main
      [cocina_display.main_title]
    when :additional
      cocina_display.additional_titles
    else
      raise ArgumentError, "Invalid title type: #{type}"
    end
  end

  def created
    Time.parse(public_cocina_doc['created'])
  end

  def modified
    Time.parse(public_cocina_doc['modified'])
  end

  def content_type
    public_cocina_doc['type'].split('/').last
  end

  def files
    cocina_structural&.fetch('contains', [])&.flat_map { |fileset| fileset.dig('structural', 'contains') } || []
  end

  def public_cocina?
    public_cocina.present?
  end

  def collection?
    content_type == 'collection'
  end

  def public?
    [cocina_access['view'], cocina_access['download']].include? 'world'
  end
end
