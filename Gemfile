# frozen_string_literal: true

source 'https://rubygems.org'

gem 'traject', '~> 3.0'

group :development, :test do
  gem 'debug', platforms: %i[mri]
  gem 'rspec'
  gem 'rubocop', require: false
  gem 'simplecov', require: false
  gem 'webmock'
end

gem 'config'
gem 'csv'
gem 'debouncer'
gem 'dor-rights-auth'
gem 'honeybadger'
gem 'http'
gem 'i18n'
gem 'iso-639'
gem 'mods_display', '~> 1.0'
gem 'parallel'
gem 'pg', platform: :mri
gem 'rake'
gem 'retriable'
gem 'ruby-kafka'
gem 'stanford-mods', '~> 3.0'
gem 'statsd-ruby'
gem 'whenever'
gem 'zeitwerk'

group :deployment do
  gem 'capistrano', '~> 3.0'
  gem 'capistrano-bundler'
  gem 'capistrano-shared_configs'
  gem 'dlss-capistrano'
end

gem 'activesupport', '~> 7.0'
gem 'slop'

gem 'cocina-models'
gem 'dor-event-client'
gem 'factory_bot', '~> 6.2'
gem 'stanford-geo', '0.2.0'

# traject brings in httpclient, and we'll need this for ruby 3.4 support:
gem 'mutex_m'
