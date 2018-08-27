#!/usr/bin/env bash

# Fires off indexing of all of the Marc data in $MARC_LOC
# SOLR_URL, RESERVES_FILE, and NUM_THREADS should also be supplied

# Kill all of the traject processes w/:
# ps aux | grep traject | awk '{print $2}' | xargs kill -9

DATE_WITH_TIME=`date "+%Y%m%d-%H%M%S"`
echo -e "Creating indexing processes based off of size (largest first)"
for file in `ls -S $MARC_LOC/*.marc`; do
    LOG_DIR=$MARC_LOC/logs/$DATE_WITH_TIME
    mkdir -p $LOG_DIR
    echo -e "\nCreating indexing process for $file"
    nohup bundle exec traject -c ./lib/traject/config/sirsi_config.rb \
        -s solr_writer.max_skipped=-1 \
        -s log.file=$LOG_DIR/$(basename $file).log $file \
        &> $LOG_DIR/$(basename $file).command.log &
    read -p 'Waiting for 10 seconds before creating the next one' -t 10
done
