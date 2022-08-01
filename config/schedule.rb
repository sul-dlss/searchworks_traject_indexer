# and also redirect stderr to stdout to honeybadger doesn't complain
job_type :honeybadger_wrapped_jruby_script, "cd :path && :environment_variable=:environment TRAJECT_ENV=:traject_env /usr/local/rvm/bin/rvm jruby-9.3.4.0 do bundle exec honeybadger exec -e :environment::traject_env -q script/:task"

job_type :honeybadger_wrapped_ruby_script, "cd :path && :environment_variable=:environment SIRSI_SERVER=:sirsi_server PURL_FETCHER_URL=:purl_fetcher_url PURL_FETCHER_TARGET=:purl_fetcher_target OKAPI_URL=:okapi_url KAFKA_CONSUMER_GROUP_ID=:kafka_consumer_group_id KAFKA_TOPIC=:kafka_topic SOLR_URL=:solr_url /usr/local/rvm/bin/rvm default do bundle exec honeybadger exec -e :environment::sirsi_server -q script/:task"

# index + delete SDR
every '* * * * *' do
  honeybadger_wrapped_jruby_script 'load_sdr.sh', traject_env: 'sdr'
end

# index + delete SDR
every '* * * * *' do
  honeybadger_wrapped_jruby_script 'load_sdr.sh', traject_env: 'sdr_stage'
end

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
every :hour do
  honeybadger_wrapped_ruby_script 'load_folio.sh', sirsi_server: 'folio', solr_url: 'http://sul-solr-prod.stanford.edu/solr/searchworks-folio-dev', okapi_url: 'https://okapi-dev.stanford.edu', kafka_topic: :marc_folio
end
