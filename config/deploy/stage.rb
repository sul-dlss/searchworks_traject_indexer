# frozen_string_literal: true

server 'sw-indexing-stage-a.stanford.edu', user: 'indexer', roles: %w[app stage]
set :procfile_env_suffix, 'stage'

Capistrano::OneTimeKey.generate_one_time_key!
