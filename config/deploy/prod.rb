server 'searchworks-indexing-prod.stanford.edu', user: 'indexer', roles: %w(app run_cron)

Capistrano::OneTimeKey.generate_one_time_key!
