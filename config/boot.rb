# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

require 'active_support/core_ext/enumerable'

Config.setup do |config|
  config.const_name = 'Settings'
  config.use_env = true
  config.env_separator = '__'
end

Config.load_and_set_settings(Config.setting_files(__dir__, ENV.fetch('TRAJECT_ENV', nil)))

loader = Zeitwerk::Loader.new
loader.inflector.inflect(
  'lc' => 'LC'
)
loader.collapse("#{__dir__}/../lib/traject/*")
loader.push_dir("#{__dir__}/../lib")
loader.setup

# We must set the load path so that Traject can find translation maps
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
