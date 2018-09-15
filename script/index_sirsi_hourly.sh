#!/usr/bin/env bash
set -e

REMOTE_DATA_DIR=/s/SUL/Dataload/SearchWorksPartday/Output
REMOTE_CREZ_DIR=/s/SUL/Dataload/SearchworksReserves/Data

LOCAL_DATA_DIR=/data/sirsi/${SIRSI_SERVER}
LOCAL_CREZ_DIR=$LOCAL_DATA_DIR/crez
LATEST_DATA_DIR=$LOCAL_DATA_DIR/latest/updates
LOG_DIR=$LATEST_DATA_DIR/logs
DEL_KEYS_FNAME="ckeys_delete.del"
RECORDS_FNAME="uni_partday.marc"
TIMESTAMP=`eval date +%y%m%d_%H%M%S`
LOG_FILE=$LOG_DIR/$RECORDS_FNAME"_"$TIMESTAMP".txt"

# create directory for data files
mkdir -p $LATEST_DATA_DIR
mkdir -p $LOCAL_CREZ_DIR

# sftp remote marc files to "latest/updates"
sftp -o "IdentityFile=~/.ssh/${SIRSI_SERVER}_id_rsa" sirsi@${SIRSI_SERVER}:$REMOTE_DATA_DIR/$DEL_KEYS_FNAME $LATEST_DATA_DIR/
sftp -o "IdentityFile=~/.ssh/${SIRSI_SERVER}_id_rsa" sirsi@${SIRSI_SERVER}:$REMOTE_DATA_DIR/$RECORDS_FNAME $LATEST_DATA_DIR/

# get crez data
full_remote_file_name=`ssh -i ~/.ssh/${SIRSI_SERVER}_id_rsa sirsi@${SIRSI_SERVER} ls -t $REMOTE_CREZ_DIR/reserves-data.* | head -1`
scp -p -i ~/.ssh/${SIRSI_SERVER}_id_rsa sirsi@${SIRSI_SERVER}:$full_remote_file_name $LOCAL_CREZ_DIR

# set RESERVES_FILE to crez file
export RESERVES_FILE=$LOCAL_CREZ_DIR/$(basename $full_remote_file_name)

# set JRUBY_OPTS and NUM_THREADS
export NUM_THREADS=2
export JRUBY_OPTS="-J-Xmx1200m"

# create log directory
mkdir -p $LOG_DIR

# index files
bundle exec traject -c ./lib/traject/config/sirsi_config.rb \
  -s solr_writer.max_skipped=-1 \
  -s log.file=$LOG_FILE \
  $LATEST_DATA_DIR/$RECORDS_FNAME

# delete records
bundle exec traject -c ./lib/traject/config/delete_config.rb \
  -s solr_writer.max_skipped=-1 \
  -s log.file=$LOG_FILE \
  $LATEST_DATA_DIR/$DEL_KEYS_FNAME
