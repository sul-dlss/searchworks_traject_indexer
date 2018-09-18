server 'searchworks-indexing-prod.stanford.edu', user: 'indexer', roles: %w(app prod)

Capistrano::OneTimeKey.generate_one_time_key!
