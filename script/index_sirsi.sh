#!/usr/bin/env bash
set -e

LOCAL_DATA_DIR=/data/sirsi/${SIRSI_SERVER}
LOCAL_CREZ_DIR=$LOCAL_DATA_DIR/crez
LATEST_DATA_DIR=$LOCAL_DATA_DIR/latest/updates
LOG_DIR=$LATEST_DATA_DIR/logs
TIMESTAMP=`eval date +%y%m%d_%H%M%S`

LOG_FILE=$LOG_DIR/$RECORDS_FNAME"_"$TIMESTAMP".txt"

# get crez data
full_remote_file_name=`ls -t $LOCAL_CREZ_DIR/reserves-data.* | head -1`

# set RESERVES_FILE to crez file
export RESERVES_FILE=$LOCAL_CREZ_DIR/$(basename $full_remote_file_name)

# set JRUBY_OPTS and NUM_THREADS
export NUM_THREADS=24
export JRUBY_OPTS="-J-Xmx8192m"

# create log directory
mkdir -p $LOG_DIR

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
