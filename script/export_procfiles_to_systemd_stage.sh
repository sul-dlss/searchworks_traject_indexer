#!/bin/bash

foreman export -a traject -u indexer -e indexing.env -f Procfile.stage --root /opt/app/indexer/searchworks_traject_indexer/current --formation marc_bodoni_dev_indexer=1,marc_morison_dev_indexer=1,folio_dev_indexer=8,sw_dev_indexer=2,sw_preview_stage_indexer=2,earthworks_stage_indexer=1 systemd ~/service_templates