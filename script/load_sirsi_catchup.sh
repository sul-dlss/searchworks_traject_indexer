#!/usr/bin/env bash
set -e

SCRIPT_NAME=$0
SCRIPT_FULL_PATH=$(dirname "$0")

LOCAL_DATA_DIR=/data/sirsi/${SIRSI_SERVER}
LATEST_DATA_DIR=$LOCAL_DATA_DIR/latest

# Index any nightlies we need to index to catch up
read -r FULL_DUMP_DATE <$LATEST_DATA_DIR/files_counts
d="${FULL_DUMP_DATE:0:4}-${FULL_DUMP_DATE:4:2}-${FULL_DUMP_DATE:6:2}"
while [ "$d" != `date -I` ]; do
  $SCRIPT_FULL_PATH/load_sirsi_nightly.sh `date -d $d +%y%m%d`
  d=$(date -I -d "$d + 1 day")
done

# And index the current nightly
$SCRIPT_FULL_PATH/load_sirsi_nightly.sh

# Latest hourly file indexed through cron
