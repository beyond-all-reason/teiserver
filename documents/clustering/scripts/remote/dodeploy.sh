#!/usr/bin/env bash# Setup folders

# vi /scripts/deploy.sh
echo "Starting release (no reboot)"
cd /
rm -r /apps/clustering_release
mkdir -p /apps/clustering_release
cd /apps/clustering_release

echo "Decompressing"
tar mxfz /releases/clustering.tar.gz

echo "Backup existing"
rm -rf /apps/central_backup
mv /apps/central /apps/central_backup

echo "Stopping service"
/apps/central/bin/central_backup stop
sudo systemctl stop clustering.service

echo "Remove existing binary"
sudo rm -rf /apps/clustering

echo "Relocate binary"
cp -r opt/build/clustering/_build/prod/rel/clustering /apps

echo "Rotate logs"
rm /var/log/central/error_old.log
rm /var/log/central/info_old.log

cp /var/log/central/error.log /var/log/central/error_old.log
cp /var/log/central/info.log /var/log/central/info_old.log

echo "Reset logs"
> /var/log/central/error.log
> /var/log/central/info.log

# Reset permissions
sudo chown -R deploy:deploy /apps/central
sudo chown -R deploy:deploy /var/log/central

echo "Starting service"
sudo systemctl start clustering.service
