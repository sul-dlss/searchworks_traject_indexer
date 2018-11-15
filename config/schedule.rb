# and also redirect stderr to stdout to honeybadger doesn't complain
job_type :honeybadger_wrapped_script,  "cd :path && :environment_variable=:environment KAFKA_TOPIC=:kafka_topic SIRSI_SERVER=:sirsi_server SOLR_URL=:solr_url bundle exec honeybadger exec -q script/:task"
job_type :honeybadger_wrapped_mri_ruby_script, "cd :path && :environment_variable=:environment KAFKA_TOPIC=:kafka_topic SOLR_URL=:solr_url /usr/local/rvm/bin/rvm ruby-2.4.4 do  bundle exec honeybadger exec -q script/:task"

# index + delete SDR
every '*/15 * * * *' do
  honeybadger_wrapped_mri_ruby_script 'index_sdr.sh', solr_url: '${SOLR_URL}'
  honeybadger_wrapped_mri_ruby_script 'delete_sdr.sh', solr_url: '${SOLR_URL}'
  honeybadger_wrapped_script 'index_sirsi.sh', sirsi_server: 'bodoni', solr_url: '${SOLR_URL}', kafka_topic: :marc_bodoni
  honeybadger_wrapped_script 'index_sirsi.sh', sirsi_server: 'morison', solr_url: '${MORISON_SOLR_URL}', kafka_topic: :marc_morison
end

every '*/5 * * * *', roles: [:prod] do
  honeybadger_wrapped_mri_ruby_script 'index_sdr_preview.sh', solr_url: '${SDR_PREVIEW_SOLR_URL}'
  honeybadger_wrapped_mri_ruby_script 'delete_sdr_preview.sh', solr_url: '${SDR_PREVIEW_SOLR_URL}'
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
