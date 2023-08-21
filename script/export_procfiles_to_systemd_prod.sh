#!/bin/bash

foreman export -a traject -u indexer -e indexing.env -f Procfile.prod --root /opt/app/indexer/searchworks_traject_indexer/current --formation sdr_prod_indexer_catchup=2,sdr_preview_indexer=2,earthworks_prod_indexer=1,sdr_prod_indexer=8,folio_prod_indexer=8 systemd ~/service_templates
