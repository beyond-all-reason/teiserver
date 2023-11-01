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
rm -rf /apps/teiserver_backup
mv /apps/teiserver /apps/teiserver_backup

echo "Stopping service"
/apps/teiserver/bin/teiserver_backup stop
# Lets see if this allows us to restart faster
# sudo systemctl stop clustering.service

echo "Remove existing binary"
sudo rm -rf /apps/clustering

echo "Relocate binary"
cp -r opt/build/clustering/_build/prod/rel/clustering /apps

echo "Rotate logs"
rm /var/log/teiserver/error_old.log
rm /var/log/teiserver/info_old.log

cp /var/log/teiserver/error.log /var/log/teiserver/error_old.log
cp /var/log/teiserver/info.log /var/log/teiserver/info_old.log

echo "Reset logs"
> /var/log/teiserver/error.log
> /var/log/teiserver/info.log

# Reset permissions
sudo chown -R deploy:deploy /apps/teiserver
sudo chown -R deploy:deploy /var/log/teiserver

echo "Starting service"
sudo systemctl restart clustering.service
