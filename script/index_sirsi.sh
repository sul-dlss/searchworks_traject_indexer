#!/usr/bin/env bash
set -e

# set JRUBY_OPTS and NUM_THREADS
export NUM_THREADS=24
export JRUBY_OPTS="-J-Xmx8192m"

LOG_FILE=log/index_sirsi_${SIRSI_SERVER}
(
flock -n 200
# index files
bundle exec traject -c ./lib/traject/config/sirsi_config.rb \
  -s solr_writer.max_skipped=-1 \
  -s log.file=$LOG_FILE

# delete records
bundle exec traject -c ./lib/traject/config/delete_config.rb \
  -s solr_writer.max_skipped=-1 \
  -s log.file=$LOG_FILE

) 200>tmp/.index_sirsi.lock
