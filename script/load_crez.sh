#!/bin/bash

LOCAL_DATA_DIR=/data/sirsi/${SIRSI_SERVER}
LOCAL_CREZ_DIR=$LOCAL_DATA_DIR/crez
LATEST_DATA_DIR=$LOCAL_DATA_DIR/latest
LOG_DIR=$LATEST_DATA_DIR/logs
REMOTE_CREZ_DIR=/s/SUL/Dataload/SearchworksReserves/Data
TIMESTAMP=`eval date +%y%m%d_%H%M%S`

mkdir -p $LOCAL_CREZ_DIR

# get crez data
full_remote_file_name=`ssh sirsi@${SIRSI_SERVER} ls -t $REMOTE_CREZ_DIR/reserves-data.* | head -1`
scp -p sirsi@${SIRSI_SERVER}:$full_remote_file_name $LOCAL_CREZ_DIR

RESERVES_FILE=$LOCAL_CREZ_DIR/$(basename $full_remote_file_name)
LOG_FILE=$LOG_DIR/$(basename $full_remote_file_name)"_"$TIMESTAMP".txt"

bundle exec ruby script/process_crez_marc_to_kafka.rb $RESERVES_FILE > $LOG_FILE
