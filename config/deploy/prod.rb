# frozen_string_literal: true

server 'sw-indexing-prod-a.stanford.edu', user: 'indexer', roles: %w[app prod]

Capistrano::OneTimeKey.generate_one_time_key!
