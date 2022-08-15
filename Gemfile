source 'https://rubygems.org'

gem 'traject', '~> 3.0'
gem 'traject-marc4j_reader', platform: :jruby

group :development, :test do
  gem 'byebug', platform: :mri
  gem 'rspec'
  gem 'simplecov', require: false
  gem 'webmock'
  gem 'rubocop', require: false
end

gem 'http'
gem 'i18n'
gem 'manticore', platform: :jruby
gem 'rake'
gem 'ruby-kafka'
gem 'stanford-mods', '~> 3.0'
gem 'iso-639'
gem 'whenever'
gem 'honeybadger'
gem 'retriable'
gem 'mods_display', '~> 1.0'
gem 'statsd-ruby'
gem 'debouncer'
gem 'dor-rights-auth'
gem 'rexml' # required for ruby 3
gem 'config'

group :deployment do
  gem 'capistrano', '~> 3.0'
  gem 'capistrano-bundler'
  gem 'capistrano-rvm'
  gem 'capistrano-shared_configs'
  gem 'dlss-capistrano'
end

gem 'activesupport', '~> 6.0' # 7.x requires ruby 2.7+ (and our jruby is at 2.5)
gem 'dry-core', '< 0.8' # 0.8 requires ruby 2.7+
gem 'dry-container', '< 0.10' # 0.10 requires ruby 2.7+
gem 'dry-validation', '< 1.8' # 1.8 requires ruby 2.7+
gem 'dry-configurable', '< 0.14' # 0.14 requires ruby 2.7+
gem 'dry-initializer', '< 3.1' # 3.1 requires ruby 2.7+
gem 'dry-schema', '< 1.9' # 1.9 requires ruby 2.7+
gem 'dry-inflector', '< 0.3' # 0.3 requires ruby 2.7+
