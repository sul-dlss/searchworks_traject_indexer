#!/usr/bin/env bash
set -e

REMOTE_DATA_DIR=/s/SUL/Dataload/SearchWorksPartday/Output

LOCAL_DATA_DIR=/data/sirsi/${SIRSI_SERVER}
LATEST_DATA_DIR=$LOCAL_DATA_DIR/latest/updates
LOG_DIR=$LATEST_DATA_DIR/logs
DEL_KEYS_FNAME="ckeys_delete.del"
RECORDS_FNAME="uni_partday.marc"
TIMESTAMP=`eval date +%y%m%d_%H%M%S`
LOG_FILE=$LOG_DIR/$RECORDS_FNAME"_"$TIMESTAMP".txt"

# create directory for data files
mkdir -p $LATEST_DATA_DIR

# copy remote marc files to "latest/updates"
scp -p sirsi@${SIRSI_SERVER}:$REMOTE_DATA_DIR/$DEL_KEYS_FNAME $LATEST_DATA_DIR/
scp -p sirsi@${SIRSI_SERVER}:$REMOTE_DATA_DIR/$RECORDS_FNAME $LATEST_DATA_DIR/

# set JRUBY_OPTS and NUM_THREADS
export NUM_THREADS=2
export JRUBY_OPTS="-J-Xmx1200m"

# create log directory
mkdir -p $LOG_DIR

bundle exec ruby script/process_marc_to_kafka.rb $LATEST_DATA_DIR/$RECORDS_FNAME > $LOG_FILE
bundle exec ruby script/process_marc_to_kafka.rb $LATEST_DATA_DIR/$DEL_KEYS_FNAME >> $LOG_FILE
