#!/usr/bin/env bash
set -e

SCRIPT_NAME=$0
SCRIPT_FULL_PATH=$(dirname "$0")
SIRSI_SERVER=$TRAJECT_ENV

CHECK_NEWNESS=$1

REMOTE_DATA_DIR=/s/SUL/Dataload/SearchWorksDump/Output
REMOTE_CREZ_DIR=/s/SUL/Dataload/SearchworksReserves/Data

LOCAL_DATA_DIR=/data/sirsi/${SIRSI_SERVER}
LOCAL_CREZ_DIR=$LOCAL_DATA_DIR/crez
PREVIOUS_DATA_DIR=$LOCAL_DATA_DIR/previous
LATEST_DATA_DIR=$LOCAL_DATA_DIR/latest
LOG_DIR=$LATEST_DATA_DIR/logs
TIMESTAMP=`eval date +%y%m%d_%H%M%S`
START_TIME=`date +%FT%TZ`

# check if timestamp in previous files_counts is same as in latest files_counts
# if different, proceed with indexing full dump
if [ $CHECK_NEWNESS ]; then #checks if CHECK_NEWNESS is defined, else index everything
  COUNTS_FNAME=files_counts
  scp -p sirsi@${SIRSI_SERVER}:$REMOTE_DATA_DIR/$COUNTS_FNAME $LOCAL_DATA_DIR
  read -r CURRENT_SIRSI_DUMP_DATE <$LOCAL_DATA_DIR/$COUNTS_FNAME
  read -r LATEST_INDEXER_DUMP_DATE <$LATEST_DATA_DIR/$COUNTS_FNAME

  if [ $CURRENT_SIRSI_DUMP_DATE -eq $LATEST_INDEXER_DUMP_DATE ]; then
    exit 0;
  fi
fi

# "Rotate" the sirsi data directories
rm -rf $PREVIOUS_DATA_DIR
mv $LATEST_DATA_DIR $PREVIOUS_DATA_DIR
mkdir -p $LATEST_DATA_DIR

# create directory for data files
mkdir -p $LATEST_DATA_DIR
mkdir -p $LOCAL_CREZ_DIR

# scp remote marc files to "latest", preserve file timestamps
scp -p sirsi@${SIRSI_SERVER}:$REMOTE_DATA_DIR/* $LATEST_DATA_DIR/

# get crez data
full_remote_file_name=`ssh sirsi@${SIRSI_SERVER} ls -t $REMOTE_CREZ_DIR/reserves-data.* | head -1`
scp -p sirsi@${SIRSI_SERVER}:$full_remote_file_name $LOCAL_CREZ_DIR

# set RESERVES_FILE to crez file
export RESERVES_FILE=$LOCAL_CREZ_DIR/$(basename $full_remote_file_name)

# set JRUBY_OPTS and NUM_THREADS
export NUM_THREADS=24
export JRUBY_OPTS="-J-Xmx8192m"

# set SIRSI_SERVER to pass to nightly and hourly script
export SIRSI_SERVER=${SIRSI_SERVER}

# create log directory
mkdir -p $LOG_DIR

bundle exec ruby script/process_marc_to_kafka.rb $LATEST_DATA_DIR/*.marc > $LOG_DIR/$TIMESTAMP.log

# Index all the nightlies and the incremental
$SCRIPT_FULL_PATH/load_sirsi_catchup.sh
