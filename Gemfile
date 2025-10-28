# frozen_string_literal: true

source 'https://rubygems.org'

gem 'traject', '~> 3.0'

group :development, :test do
  gem 'debug', platforms: %i[mri]
  gem 'rspec'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'simplecov', require: false
  gem 'webmock'
end

gem 'config'
gem 'csv'
gem 'debouncer'
gem 'honeybadger'
gem 'http'
gem 'i18n'
gem 'iso-639'
gem 'mods_display', '~> 1.0'
gem 'parallel'
gem 'pg', platform: :mri
gem 'rake'
gem 'retriable'
gem 'roman_numerals', '~> 1.0'
gem 'ruby-kafka'
gem 'stanford-mods', '~> 3.0'
gem 'statsd-ruby'
gem 'whenever', require: false # Work around https://github.com/javan/whenever/issues/831
gem 'zeitwerk'

group :deployment do
  gem 'capistrano', '~> 3.0'
  gem 'capistrano-bundler'
  gem 'capistrano-shared_configs'
  gem 'dlss-capistrano'
end

gem 'activesupport', '~> 8.0'
gem 'slop'

gem 'cocina_display', '~> 1.2'
gem 'dor-event-client'
gem 'factory_bot', '~> 6.2'
gem 'stanford-geo', '0.2.0'

# traject brings in httpclient, and we'll need this for ruby 3.4 support:
gem 'mutex_m'

gem 'match_map', '~> 3.0'
