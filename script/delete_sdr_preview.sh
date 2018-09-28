#!/bin/bash
set -e

STATE_FILE=tmp/searchworks_traject_indexer_preview_delete_last_run
CURRENT_DATE=`date --rfc-3339=seconds`
LOG_FILE=tmp/delete_sdr_preview_log

(
flock -n 200
read -r LAST_DATE <$STATE_FILE

export JRUBY_OPTS="-J-Xmx8192m"
bundle exec traject -c ./lib/traject/config/sdr_delete_config.rb -s purl_fetcher.target="" -s skip_if_catkey=false -s purl_fetcher.first_modified="${LAST_DATE}" -s solr_writer.max_skipped=-1 -s log.file=$LOG_FILE.log /dev/null

echo $CURRENT_DATE > $STATE_FILE
) 200>tmp/.delete_sdr_preview.lock
