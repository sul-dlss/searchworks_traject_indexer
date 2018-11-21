#!/usr/bin/env bash
set -e

LOG_FILE=log/index_sdr_log_${KAFKA_CONSUMER_GROUP_ID}

(
flock -n 200 || exit 0
# index files
bundle exec traject -c ./lib/traject/config/sdr_config.rb \
  -s solr_writer.max_skipped=-1

export SOURCE=sdr
# delete records
bundle exec traject -c ./lib/traject/config/delete_config.rb \
  -s solr_writer.max_skipped=-1

) 200>tmp/.index_sdr.lock
