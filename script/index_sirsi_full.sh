#!/usr/bin/env bash
set -e

SCRIPT_NAME=$0
SCRIPT_FULL_PATH=$(dirname "$0")

REMOTE_DATA_DIR=/s/SUL/Dataload/SearchWorksDump/Output
REMOTE_CREZ_DIR=/s/SUL/Dataload/SearchworksReserves/Data

LOCAL_DATA_DIR=/data/sirsi
LOCAL_CREZ_DIR=/data/sirsi/crez
PREVIOUS_DATA_DIR=$LOCAL_DATA_DIR/previous
LATEST_DATA_DIR=$LOCAL_DATA_DIR/latest
LOG_DIR=$LATEST_DATA_DIR/logs
TIMESTAMP=`eval date +%y%m%d_%H%M%S`
START_TIME=`date +%FT%TZ`

# "Rotate" the sirsi data directories
rm -rf $PREVIOUS_DATA_DIR
mv $LATEST_DATA_DIR $PREVIOUS_DATA_DIR
mkdir -p $LATEST_DATA_DIR

# create directory for data files
mkdir -p $LATEST_DATA_DIR
mkdir -p $LOCAL_CREZ_DIR

# sftp remote marc files to "latest"
sftp -o 'IdentityFile=~/.ssh/id_rsa' sirsi@bodoni:$REMOTE_DATA_DIR/* $LATEST_DATA_DIR/

# get crez data
full_remote_file_name=`ssh -i ~/.ssh/id_rsa sirsi@bodoni ls -t $REMOTE_CREZ_DIR/reserves-data.* | head -1`
scp -p -i ~/.ssh/id_rsa sirsi@bodoni:$full_remote_file_name $LOCAL_CREZ_DIR

# set RESERVES_FILE to crez file
export RESERVES_FILE=$LOCAL_CREZ_DIR/$(basename $full_remote_file_name)

# set JRUBY_OPTS and NUM_THREADS
export NUM_THREADS=24
export JRUBY_OPTS="-J-Xmx8192m"

# create log directory
mkdir -p $LOG_DIR

bundle exec traject -c ./lib/traject/config/sirsi_config.rb \
    -s solr_writer.max_skipped=-1 \
    -s log.file=$LOG_DIR/$TIMESTAMP.log $LATEST_DATA_DIR/*.marc

# Index any nightlies we need to index to catch up
read -r FULL_DUMP_DATE <$LATEST_DATA_DIR/files_counts
d="${FULL_DUMP_DATE:0:4}-${FULL_DUMP_DATE:4:2}-${FULL_DUMP_DATE:6:2}"
while [ "$d" != `date -I` ]; do
  d=$(date -I -d "$d + 1 day")
  $SCRIPT_FULL_PATH/index_sirsi_nightly.sh `date -d $d +%y%m%d`
done

# Index the current incremental file
$SCRIPT_FULL_PATH/index_sirsi_hourly.sh

# TODO: Clean up any records that weren't in the dump
