# and also redirect stderr to stdout to honeybadger doesn't complain
job_type :honeybadger_wrapped_jruby_script, "cd :path && :environment_variable=:environment SIRSI_SERVER=:sirsi_server PURL_FETCHER_URL=:purl_fetcher_url PURL_FETCHER_TARGET=:purl_fetcher_target KAFKA_CONSUMER_GROUP_ID=:kafka_consumer_group_id KAFKA_TOPIC=:kafka_topic SOLR_URL=:solr_url /usr/local/rvm/bin/rvm jruby-9.2.17.0 do bundle exec honeybadger exec -e :environment::sirsi_server -q script/:task"

# index + delete SDR
every '* * * * *' do
  honeybadger_wrapped_jruby_script 'load_sdr.sh', sirsi_server: 'sdr', kafka_topic: :purl_fetcher_prod, solr_url: '${SOLR_URL}', purl_fetcher_url: 'https://purl-fetcher.stanford.edu'
end

# index + delete SDR
every '* * * * *' do
  honeybadger_wrapped_jruby_script 'load_sdr_stage.sh', sirsi_server: 'sdr', kafka_topic: :purl_fetcher_stage, solr_url: '${SOLR_URL}', purl_fetcher_url: 'https://purl-fetcher-stage.stanford.edu'
end

# USING BODONI (prod) DATA
every '45 6-23 * * *' do
  honeybadger_wrapped_jruby_script 'load_sirsi_hourly.sh', sirsi_server: 'bodoni', solr_url: '${SOLR_URL}', kafka_topic: :marc_bodoni
end

every :day, at: '4:30am' do
  honeybadger_wrapped_jruby_script 'load_sirsi_nightly.sh', sirsi_server: 'bodoni', solr_url: '${SOLR_URL}', kafka_topic: :marc_bodoni
end

every :day, at: '12:59am' do
  honeybadger_wrapped_jruby_script 'load_sirsi_full.sh new', sirsi_server: 'bodoni', solr_url: '${SOLR_URL}', kafka_topic: :marc_bodoni
end

# USING MORISON (dev) DATA
every '15 6-23 * * *' do
  honeybadger_wrapped_jruby_script 'load_sirsi_hourly.sh', sirsi_server: 'morison', solr_url: '${MORISON_SOLR_URL}', kafka_topic: :marc_morison
end

every :day, at: '06:00am' do
  honeybadger_wrapped_jruby_script 'load_sirsi_nightly.sh', sirsi_server: 'morison', solr_url: '${MORISON_SOLR_URL}', kafka_topic: :marc_morison
end

every :day, at: '09:00pm' do
  honeybadger_wrapped_jruby_script 'load_sirsi_full.sh new', sirsi_server: 'morison', solr_url: '${MORISON_SOLR_URL}', kafka_topic: :marc_morison
end
