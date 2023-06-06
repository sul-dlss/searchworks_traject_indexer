#!/bin/bash

# disable/remove old rules
sudo systemctl stop traject.target
sudo systemctl disable traject.target

sudo cp /opt/app/indexer/service_templates/* /usr/lib/systemd/system/

sudo systemctl enable traject.target
sudo systemctl start traject.target
