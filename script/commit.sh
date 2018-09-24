#!/bin/bash
set -e

bundle exec traject -x commit -c ./lib/traject/config/sirsi_config.rb 2>&1
