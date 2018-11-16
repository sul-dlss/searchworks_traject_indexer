#!/usr/bin/env bash
set -e

LOG_FILE=tmp/load_sdr_log

SCRIPT_NAME=$0
SCRIPT_FULL_PATH=$(dirname "$0")

bundle exec ruby script/process_purl_fetcher_to_kafka.rb > $LOG_FILE.log
