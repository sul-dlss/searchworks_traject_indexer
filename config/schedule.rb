# frozen_string_literal: true

# and also redirect stderr to stdout to honeybadger doesn't complain
job_type :honeybadger_wrapped_jruby_script,
         'cd :path && :environment_variable=:environment TRAJECT_ENV=:traject_env /usr/local/rvm/bin/rvm jruby-9.4.1.0 do bundle exec honeybadger exec -e :environment::traject_env -q script/:task'

job_type :honeybadger_wrapped_ruby_script,
         'cd :path && :environment_variable=:environment TRAJECT_ENV=:traject_env /usr/local/rvm/bin/rvm ruby-3.1.2 do bundle exec honeybadger exec -e :environment::traject_env -q script/:task'

# USING BODONI (prod) DATA
every '45 6-23 * * *' do
  honeybadger_wrapped_jruby_script 'load_sirsi_hourly.sh', traject_env: 'bodoni'
end

every :day, at: '4:30am' do
  honeybadger_wrapped_jruby_script 'load_sirsi_nightly.sh', traject_env: 'bodoni'
end

every :day, at: '12:59am' do
  honeybadger_wrapped_jruby_script 'load_sirsi_full.sh new', traject_env: 'bodoni'
end

# USING MORISON (dev) DATA
every '15 6-23 * * *' do
  honeybadger_wrapped_jruby_script 'load_sirsi_hourly.sh', traject_env: 'morison'
end

every :day, at: '06:00am' do
  honeybadger_wrapped_jruby_script 'load_sirsi_nightly.sh', traject_env: 'morison'
end

every :day, at: '09:00pm' do
  honeybadger_wrapped_jruby_script 'load_sirsi_full.sh new', traject_env: 'morison'
end

# USING FOLIO DATA
every '*/5 * * * *', roles: [:stage] do
  honeybadger_wrapped_ruby_script 'load_folio_postgres.sh', traject_env: 'folio_test'
end
