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
    catkey.presence || druid
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

  # Ensure all objects, even those missing public xml/cocina have a (nil) catkey and a label
  delegate :catkey, to: :public_cocina, allow_nil: true
  delegate :label, to: :public_cocina, allow_nil: true

  delegate :mods, :collection?,
           :thumb, :dor_content_type, :dor_resource_content_type, :dor_file_mimetype,
           :dor_resource_count, :collections, :constituents,
           :stanford_mods, :mods_display,
           :public_xml_doc, to: :public_xml

  delegate :content_type, :files, to: :public_cocina

  delegate :released_to_earthworks?, :released_to_searchworks?, to: :public_meta_json

  # TODO: remove after updating traject configs to use cocina_display methods
  alias cocina_display public_cocina

  # TODO: remove after updating the config to use cocina_display methods
  def cocina_titles(type: :main)
    case type
    when :main
      [public_cocina.main_title]
    when :additional
      public_cocina.additional_titles
    else
      raise ArgumentError, "Invalid title type: #{type}"
    end
  end

  # TODO: remove after updating traject configs to use cocina_display methods
  def created
    public_cocina.created_time
  end

  # TODO: remove after updating traject configs to use cocina_display methods
  def modified
    public_cocina.modified_time
  end

  # TODO: remove after updating traject configs to use cocina_display methods
  def public?
    public_cocina.world_viewable?
  end

  # TODO: remove after updating traject configs to use cocina_display methods
  def public_cocina_doc
    public_cocina&.cocina_doc
  end

  # TODO: remove after updating traject configs to use cocina_display methods
  def cocina_structural
    public_cocina&.cocina_doc&.dig('structural')
  end

  # TODO: remove after updating traject configs to use cocina_display methods
  def cocina_description
    public_cocina&.cocina_doc&.dig('description')
  end
end
