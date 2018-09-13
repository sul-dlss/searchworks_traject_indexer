set :output, 'log/cron.log'

# index + delete SDR
every '*/15 * * * *' do
  script 'index_sdr.sh'
  script 'delete_sdr.sh'
end

every '45 6-23 * * *' do
  script 'index_sirsi_hourly.sh'
end

every :day, at: '4:30am' do
  script 'index_sirsi_nightly.sh'
end

every :day, at: '1:00am' do
  script 'index_sirsi_full.sh'
end
