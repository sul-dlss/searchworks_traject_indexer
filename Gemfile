source 'https://rubygems.org'

gem 'traject', '~> 3.0a'
gem 'traject-marc4j_reader', git: 'https://github.com/traject/traject-marc4j_reader', branch: 'master', platform: :jruby

group :development, :test do
  gem 'byebug', platform: :mri
  gem 'rspec'
end

gem 'http'
gem 'i18n'
gem 'manticore', platform: :jruby
gem 'rake'
gem 'stanford-mods'
gem 'whenever'
gem 'honeybadger'

group :deployment do
  gem 'capistrano', '~> 3.0'
  gem 'capistrano-bundler'
  gem 'capistrano-rvm'
  gem 'capistrano-shared_configs'
  gem 'dlss-capistrano'
end
