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

  def cocina_access
    @cocina_access ||= Cocina::Models::DROAccess.new(public_cocina_doc['access'])
  end

  def public?
    [cocina_access.view, cocina_access.download].include? 'world'
  end

  def stanford_only?
    [cocina_access.view, cocina_access.download].include? 'stanford'
  end

  def cocina_description
    @cocina_description ||= Cocina::Models::Description.new(public_cocina_doc['description'])
  end

  def title
    @title ||= Cocina::Models::Builders::TitleBuilder.build(cocina_description.title)
  end

  def resource_type
    @resource_type ||= cocina_description.geographic.first.form.find { |form| form.type == 'type' }
  end

  def event_dates
    @event_dates ||= cocina_description.event.find { |event| !event.date.nil? }.date
  end

  def event_contributors
    @event_contributors ||= cocina_description.event.map { |event| event.contributor unless event.contributor.empty? }.flatten
  end

  def publication_date
    @publication_date ||= event_dates.find { |event_date| event_date.type == 'publication' }
  end

  def data_format
    @data_format ||= cocina_description.geographic.first.form.find { |form| form.type == 'data format' }
  end

  # TODO: Determine how to provide the value (i.e. English) with the code (i.e. eng)
  def languages
    @languages ||= cocina_description.language.map { |lang| { code: lang.code } if lang.code }.compact
  end

  def topics
    @topics ||= cocina_description.subject.select { |subject| subject.type == 'topic' }
  end

  def themes
    @themes ||= topics.select { |topic| topic.source.code == 'ISO19115TopicCategory' }
  end

  def geographic
    @geographic ||= cocina_description.geographic
  end

  def geographic_spatial
    @geographic_spatial ||= geographic.find(&:subject).subject.find { |subject| subject.type == 'coverage' }
  end

  def contibutors
    @contibutors ||= cocina_description.contributor
  end

  def creators
    @creators ||= contibutors.select { |contributor| contributor.role.find { |role| role.value == 'creator' } }
  end

  def publishers
    @publishers ||= event_contributors.select do |contributor|
      unless contributor.role.empty? contributor.role.find { |role| role.value == 'publisher' }
    end
  end

  def temporal
    @temporal ||= cocina_description.subject.map { |subject| subject.structuredValue.map(&:value) if subject.type == 'time' }.compact
  end

  # TODO: add logic for -> subject*.structuredValue*.type=genre AND subject*.structuredValue*.value=Maps
  def map?
    cocina_description.form.map(&:value).include?('map') || cocina_description.title.include?('(Raster Image)')
  end

  def dataset?
    cocina_description.form.map(&:value).include?('Dataset')
  end

  def collection?
    cocina_description.form.map(&:value).include?('collection')
  end

  def extent
    @extent ||= cocina_description.form.find { |form| form.type == 'extent' }
  end
end
