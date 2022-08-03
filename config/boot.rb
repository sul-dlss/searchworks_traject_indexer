$LOAD_PATH << File.expand_path('../lib', __dir__)
require 'config'

Config.load_and_set_settings(Config.setting_files(__dir__, ENV['TRAJECT_ENV']))

require 'utils'
