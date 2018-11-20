# and also redirect stderr to stdout to honeybadger doesn't complain
job_type :honeybadger_wrapped_script,  "cd :path && :environment_variable=:environment KAFKA_TOPIC=:kafka_topic SIRSI_SERVER=:sirsi_server SOLR_URL=:solr_url bundle exec honeybadger exec -q script/:task"
job_type :honeybadger_wrapped_mri_ruby_script, "cd :path && :environment_variable=:environment PURL_FETCHER_TARGET=:purl_fetcher_target KAFKA_CONSUMER_GROUP_ID=:kafka_consumer_group_id KAFKA_TOPIC=:kafka_topic SOLR_URL=:solr_url /usr/local/rvm/bin/rvm ruby-2.5.3 do  bundle exec honeybadger exec -q script/:task"

# index + delete SDR
every '* * * * *' do
  honeybadger_wrapped_mri_ruby_script 'index_sdr.sh', solr_url: '${SOLR_URL}', kafka_topic: :purl_fetcher, purl_fetcher_target: 'Searchworks', kafka_consumer_group_id: 'traject'
  honeybadger_wrapped_mri_ruby_script 'load_sdr.sh', kafka_topic: :purl_fetcher, solr_url: '${SOLR_URL}'
end

# index + delete sirsi
every '* * * * *' do
  honeybadger_wrapped_script 'index_sirsi.sh', sirsi_server: 'bodoni', solr_url: '${SOLR_URL}', kafka_topic: :marc_bodoni
  honeybadger_wrapped_script 'index_sirsi.sh', sirsi_server: 'morison', solr_url: '${MORISON_SOLR_URL}', kafka_topic: :marc_morison
end

every '* * * * *', roles: [:prod] do
  honeybadger_wrapped_mri_ruby_script 'index_sdr.sh', solr_url: '${SDR_PREVIEW_SOLR_URL}', kafka_topic: :purl_fetcher, purl_fetcher_target: '', kafka_consumer_group_id: 'traject_preview'
end

# USING BODONI (prod) DATA
every '45 6-23 * * *' do
  honeybadger_wrapped_script 'load_sirsi_hourly.sh', sirsi_server: 'bodoni', solr_url: '${SOLR_URL}', kafka_topic: :marc_bodoni
end

every :day, at: '4:30am' do
  honeybadger_wrapped_script 'load_sirsi_nightly.sh', sirsi_server: 'bodoni', solr_url: '${SOLR_URL}', kafka_topic: :marc_bodoni
end

every :day, at: '12:59am' do
  honeybadger_wrapped_script 'load_sirsi_full.sh new', sirsi_server: 'bodoni', solr_url: '${SOLR_URL}', kafka_topic: :marc_bodoni
end

# USING MORISON (dev) DATA
every '15 6-23 * * *' do
  honeybadger_wrapped_script 'load_sirsi_hourly.sh', sirsi_server: 'morison', solr_url: '${MORISON_SOLR_URL}', kafka_topic: :marc_morison
end

every :day, at: '06:00am' do
  honeybadger_wrapped_script 'load_sirsi_nightly.sh', sirsi_server: 'morison', solr_url: '${MORISON_SOLR_URL}', kafka_topic: :marc_morison
end

every :day, at: '09:00pm' do
  honeybadger_wrapped_script 'load_sirsi_full.sh new', sirsi_server: 'morison', solr_url: '${MORISON_SOLR_URL}', kafka_topic: :marc_morison
end
