#!/usr/bin/env bash
set -e

LOG_FILE=tmp/load_folio_items_log

SCRIPT_NAME=$0
SCRIPT_FULL_PATH=$(dirname "$0")

(
flock -n 200 || exit 0

bundle exec ruby script/process_folio_item_changes_to_kafka.rb > $LOG_FILE.log

) 200>tmp/.load_folio_items.lock
