#!/bin/bash
set -e

STATE_FILE=tmp/searchworks_traject_indexer_last_run
CURRENT_DATE=`date --rfc-3339=seconds`
export NUM_THREADS=8
LOG_FILE=tmp/index_sdr_log
ALL_MODS=$1

if [ $ALL_MODS ]; then #checks if ALL_MODS is defined, else index only latest
  LAST_DATE="2000-01-01 00:00:05-07:00"
else
  read -r LAST_DATE <$STATE_FILE
fi

(
flock -n 200

export JRUBY_OPTS="-J-Xmx8192m"
bundle exec traject -c ./lib/traject/config/sdr_config.rb -s purl_fetcher.first_modified="${LAST_DATE}" -s solr_writer.max_skipped=-1 -s log.file=$LOG_FILE /dev/null

echo $CURRENT_DATE > $STATE_FILE
) 200>tmp/.index_sdr.lock
