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
end
