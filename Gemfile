source 'https://rubygems.org'

gem 'traject', '~> 3.0'
gem 'traject-marc4j_reader', platform: :jruby

group :development, :test do
  gem 'byebug', platform: :mri
  gem 'rspec'
  gem 'simplecov', require: false
end

gem 'http'
gem 'i18n'
gem 'manticore', platform: :jruby
gem 'rake'
gem 'ruby-kafka'
gem 'stanford-mods'
gem 'iso-639', '< 0.3' # v0.3+ requires ruby 2.6+ (and out jruby is at 2.5)
gem 'whenever'
gem 'honeybadger'
gem 'retriable'
gem 'mods_display'
gem 'statsd-ruby'
gem 'debouncer'
gem 'dor-rights-auth'
gem 'rexml' # required for ruby 3

group :deployment do
  gem 'capistrano', '~> 3.0'
  gem 'capistrano-bundler'
  gem 'capistrano-rvm'
  gem 'capistrano-shared_configs'
  gem 'dlss-capistrano'
end

gem 'activesupport', '~> 6.0' # 7.x requires ruby 2.7+ (and our jruby is at 2.5)
