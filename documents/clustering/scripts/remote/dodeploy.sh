#!/usr/bin/env bash# Setup folders

# vi /scripts/deploy.sh
echo "Starting release (no reboot)"
cd /
rm -r /apps/clustering_release
mkdir -p /apps/clustering_release
cd /apps/clustering_release

echo "Decompressing"
tar mxfz /releases/clustering.tar.gz

echo "Stopping service"
sudo systemctl stop clustering.service

echo "Remove existing binary"
sudo rm -rf /apps/clustering

echo "Relocate binary"
cp -r opt/build/clustering/_build/prod/rel/clustering /apps

echo "Reset logs"
> /var/log/nginx/error.log
> /var/log/clustering/error.log
> /var/log/clustering/info.log

echo "Starting service"
sudo systemctl start clustering.service
