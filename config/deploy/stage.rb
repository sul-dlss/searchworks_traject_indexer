server 'sw-indexing-stage-a.stanford.edu', user: 'indexer', roles: %w(app)

Capistrano::OneTimeKey.generate_one_time_key!
