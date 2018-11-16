#!/usr/bin/env bash
set -e

LOG_FILE=tmp/index_sdr_log

(
flock -n 200
# index files
bundle exec traject -c ./lib/traject/config/sdr_config.rb \
  -s solr_writer.max_skipped=-1 \
  -s log.file=$LOG_FILE

export SOURCE=sdr
# delete records
bundle exec traject -c ./lib/traject/config/delete_config.rb \
  -s solr_writer.max_skipped=-1 \
  -s log.file=$LOG_FILE

) 200>tmp/.index_sdr.lock
