# frozen_string_literal: true

server 'sw-indexing-prod-a.stanford.edu', user: 'indexer', roles: %w[app prod]
set :procfile_env_suffix, 'prod'

Capistrano::OneTimeKey.generate_one_time_key!
