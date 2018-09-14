job_type :honeybadger_wrapped_script,  "cd :path && :environment_variable=:environment SIRSI_SERVER=:sirsi_server SOLR_URL=:solr_url bundle exec script/honeybadger-custom-exec.rb exec -q script/:task :output"
job_type :honeybadger_wrapped_mri_ruby_script, "cd :path && :environment_variable=:environment /usr/local/rvm/bin/rvm ruby-2.4.4 do  bundle exec script/honeybadger-custom-exec.rb exec -q script/:task :output"

# index + delete SDR
every '*/15 * * * *' do
  honeybadger_wrapped_mri_ruby_script 'index_sdr.sh'
  honeybadger_wrapped_mri_ruby_script 'delete_sdr.sh'
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
