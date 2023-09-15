# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

Config.setup do |config|
  config.const_name = 'Settings'
  config.use_env = true
  config.env_separator = '__'
end

Config.load_and_set_settings(Config.setting_files(__dir__, ENV.fetch('TRAJECT_ENV', nil)))

# jRuby 9.4.1.0 does not yet support zeitwerk
# See: https://github.com/jruby/jruby/issues/6781
# loader = Zeitwerk::Loader.new
# loader.inflector.inflect(
#   'lc' => 'LC'
# )
# loader.collapse("#{__dir__}/../lib/traject/*")
# loader.push_dir("#{__dir__}/../lib")
# loader.setup

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'call_numbers/call_number_base'
require 'call_numbers/shelfkey_base'
require 'call_numbers/shelfkey'
require 'call_numbers/other'
require 'call_numbers/lc'
require 'call_numbers/dewey'
require 'call_numbers/dewey_shelfkey'

require 'constants'
require 'folio_client'
require 'folio_record'
require 'folio/eresource_holdings_builder'
require 'folio/holdings'
require 'folio/marc_record_instance_mapper'
require 'folio/marc_record_mapper'
require 'folio/mhld_builder'
require 'folio/status_current_location'
require 'folio/types'
require 'libraries_map'
require 'locations_map'
require 'marc_links'
require 'mhld_field'
require 'public_xml_record'
require 'utils'
require 'traject/extractors/folio_kafka_extractor'
require 'traject/extractors/marc_kafka_extractor'
require 'traject/readers/druid_reader'
require 'traject/readers/kafka_purl_fetcher_reader'
require 'traject/readers/marc_combining_reader'
require 'traject/readers/folio_postgres_reader'
require 'traject/writers/solr_better_json_writer'
require 'traject/common/marc_utils'
