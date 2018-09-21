#!/usr/bin/env bash
set -e

SCRIPT_NAME=$0
SCRIPT_FULL_PATH=$(dirname "$0")

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

# "Rotate" the sirsi data directories
rm -rf $PREVIOUS_DATA_DIR
mv $LATEST_DATA_DIR $PREVIOUS_DATA_DIR
mkdir -p $LATEST_DATA_DIR

# create directory for data files
mkdir -p $LATEST_DATA_DIR
mkdir -p $LOCAL_CREZ_DIR

# check if timestamp in previous files_counts is same as in latest files_counts
# if different, proceed with indexing full dump
if [ $CHECK_NEWNESS ]; then #checks if CHECK_NEWNESS is defined, else index everything
  COUNTS_FNAME=files_counts
  scp -p sirsi@${SIRSI_SERVER}:$REMOTE_DATA_DIR/$COUNTS_FNAME $LOCAL_DATA_DIR

  if [ $LATEST_DATA_DIR/$COUNTS_FNAME -nt $LOCAL_DATA_DIR/$COUNTS_FNAME ]; then
    exit 0;
  fi
fi

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

bundle exec traject -c ./lib/traject/config/sirsi_config.rb \
    -s solr_writer.max_skipped=-1 \
    -s log.file=$LOG_DIR/$TIMESTAMP.log $LATEST_DATA_DIR/*.marc

# Index any nightlies we need to index to catch up
read -r FULL_DUMP_DATE <$LATEST_DATA_DIR/files_counts
d="${FULL_DUMP_DATE:0:4}-${FULL_DUMP_DATE:4:2}-${FULL_DUMP_DATE:6:2}"
while [ "$d" != `date -I` ]; do
  $SCRIPT_FULL_PATH/index_sirsi_nightly.sh `date -d $d +%y%m%d`
  d=$(date -I -d "$d + 1 day")
done

# Index the current incremental file
$SCRIPT_FULL_PATH/index_sirsi_hourly.sh

# gets the numFound for documents last_updated before start of indexing full dump
# assumes numFound value is 3rd field of colon-separated line in response
#   "response":{"numFound":664,"start":0,"maxScore":1.0,"docs":[]
NUM_DOCS_TO_DEL=`curl -s -G "${SOLR_URL}"/select -d "fq=collection:sirsi&fq=last_updated:%5B*%20TO%20$START_TIME%5D&q=*:*&facet=false&rows=0" | grep "numFound" | cut -d":" -f3 | tr -d '[:alpha:]|[:punct:]'`

if [ "$NUM_DOCS_TO_DEL" -gt 100 ]; then
  # sends to honeybadger ???
  echo "Too many documents will be deleted!";
  exit 1;
else
  # delete old sirsi docs
  curl "${SOLR_URL}"/update/?commit=true -H "Content-Type: text/xml" -d "<delete><query>(collection:\"sirsi\")AND(last_updated: [* TO $START_TIME])</query></delete>"
fi
