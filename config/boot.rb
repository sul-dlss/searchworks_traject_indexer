# frozen_string_literal: true

$LOAD_PATH << File.expand_path('../lib', __dir__)
require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

Config.setup do |config|
  config.const_name = 'Settings'
  config.use_env = true
end

Config.load_and_set_settings(Config.setting_files(__dir__, ENV.fetch('TRAJECT_ENV', nil)))

loader = Zeitwerk::Loader.new
loader.inflector.inflect(
  'lc' => 'LC'
)
loader.collapse("#{__dir__}/../lib/traject/*")
loader.push_dir("#{__dir__}/../lib")
loader.setup
