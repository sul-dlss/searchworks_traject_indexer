server 'sw-indexing-dev.stanford.edu', user: 'harvestdor', roles: %w(app)

Capistrano::OneTimeKey.generate_one_time_key!
