# frozen_string_literal: true

# and also redirect stderr to stdout to honeybadger doesn't complain
job_type :honeybadger_wrapped_ruby_script,
         'cd :path && :environment_variable=:environment TRAJECT_ENV=:traject_env /usr/local/rvm/bin/rvm ruby-3.2.2 do bundle exec honeybadger exec -e :environment::traject_env -q script/:task'

# USING FOLIO DATA
every '*/5 * * * *', roles: [:stage] do
  honeybadger_wrapped_ruby_script 'load_folio_postgres.sh', traject_env: 'folio_test'
end

every '*/5 * * * *', roles: [:prod] do
  honeybadger_wrapped_ruby_script 'load_folio_postgres.sh', traject_env: 'folio_prod'
end

every '0 3 1-7 * 0', roles: [:stage] do
  honeybadger_wrapped_ruby_script 'load_folio_postgres_full.sh', traject_env: 'folio_test'
end

every '0 3 8-14 * 0', roles: [:prod] do
  honeybadger_wrapped_ruby_script 'load_folio_postgres_full.sh', traject_env: 'folio_prod'
end

every '0 22 * * 0', roles: [:stage] do
  honeybadger_wrapped_ruby_script 'load_folio_postgres_full.sh', traject_env: 'folio_prod'
end
