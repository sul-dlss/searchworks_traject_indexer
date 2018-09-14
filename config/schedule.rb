job_type :honeybadger_wrapped_script,  "cd :path && :environment_variable=:environment bundle exec honeybadger exec -q script/:task :output"
job_type :honeybadger_wrapped_mri_ruby_script, "cd :path && :environment_variable=:environment /usr/local/rvm/bin/rvm ruby-2.4.4 do  bundle exec honeybadger exec -q script/:task :output"

# index + delete SDR
every '*/15 * * * *' do
  honeybadger_wrapped_mri_ruby_script 'index_sdr.sh'
  honeybadger_wrapped_mri_ruby_script 'delete_sdr.sh'
end

every '45 6-23 * * *' do
  honeybadger_wrapped_script 'index_sirsi_hourly.sh'
end

every :day, at: '4:30am' do
  honeybadger_wrapped_script 'index_sirsi_nightly.sh'
end

every :day, at: '1:00am' do
  honeybadger_wrapped_script 'index_sirsi_full.sh new'
end
