# and also redirect stderr to stdout to honeybadger doesn't complain
job_type :honeybadger_wrapped_script,  "cd :path && :environment_variable=:environment SIRSI_SERVER=:sirsi_server SOLR_URL=:solr_url bundle exec honeybadger exec -q script/:task 2>&1"
job_type :honeybadger_wrapped_mri_ruby_script, "cd :path && :environment_variable=:environment  SOLR_URL=:solr_url /usr/local/rvm/bin/rvm ruby-2.4.4 do  bundle exec honeybadger exec -q script/:task 2>&1"

# index + delete SDR
every '*/15 * * * *' do
  honeybadger_wrapped_mri_ruby_script 'index_sdr.sh', solr_url: '${SOLR_URL}'
  honeybadger_wrapped_mri_ruby_script 'delete_sdr.sh', solr_url: '${SOLR_URL}'
end

every '*/5 * * * *', roles: [:prod] do
  honeybadger_wrapped_mri_ruby_script 'index_sdr_preview.sh', solr_url: '${SDR_PREVIEW_SOLR_URL}'
  honeybadger_wrapped_mri_ruby_script 'delete_sdr_preview.sh', solr_url: '${SDR_PREVIEW_SOLR_URL}'
end

every '45 6-23 * * *' do
  honeybadger_wrapped_script 'index_sirsi_hourly.sh', sirsi_server: 'morison', solr_url: '${MORISON_SOLR_URL}'
  honeybadger_wrapped_script 'index_sirsi_hourly.sh', sirsi_server: 'bodoni', solr_url: '${SOLR_URL}'
end

every :day, at: '4:30am' do
  honeybadger_wrapped_script 'index_sirsi_nightly.sh', sirsi_server: 'morison', solr_url: '${MORISON_SOLR_URL}'
  honeybadger_wrapped_script 'index_sirsi_nightly.sh', sirsi_server: 'bodoni', solr_url: '${SOLR_URL}'
end

every :day, at: '1:00am' do
  honeybadger_wrapped_script 'index_sirsi_full.sh new', sirsi_server: 'morison', solr_url: '${MORISON_SOLR_URL}'
  honeybadger_wrapped_script 'index_sirsi_full.sh new', sirsi_server: 'bodoni', solr_url: '${SOLR_URL}'
end


every '*/15 1-6 * * *' do
  honeybadger_wrapped_script 'commit.sh', solr_url: '${MORISON_SOLR_URL}'
  honeybadger_wrapped_script 'commit.sh', solr_url: '${SOLR_URL}'
end
