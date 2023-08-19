#!/bin/bash
set -e

bundle exec traject -x commit -c ./lib/traject/config/marc_config.rb 2>&1
