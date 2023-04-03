# Setup folders
# vi /scripts/deploy.sh
echo "Starting release (no reboot)"
cd /
rm -r /apps/central_release
mkdir -p /apps/central_release
cd /apps/central_release

echo "Decompressing"
tar mxfz /releases/teiserver.tar.gz

echo "Backup existing"
rm -rf /apps/central_backup
mv /apps/central /apps/central_backup

echo "Stopping service"
/apps/central_backup/bin/central stop
# Lets see if this allows us to restart faster
# sudo systemctl stop clustering.service

echo "Remove existing binary"
sudo rm -rf /apps/central

echo "Relocate binary"
cp -r opt/build/_build/prod/rel/central /apps

echo "Rotate logs"
rm /var/log/central/error_old.log
rm /var/log/central/info_old.log

cp /var/log/central/error.log /var/log/central/error_old.log
cp /var/log/central/info.log /var/log/central/info_old.log

sudo chmod o+rw /apps/central/releases/0.1.0/env.sh
cat /apps/ts.vars >> /apps/central/releases/0.1.0/env.sh

echo "+Q 65536" >> /apps/central/releases/0.1.0/vm.args

echo "Reset logs"
> /var/log/central/error.log
> /var/log/central/info.log

# Reset permissions
sudo chown -R deploy:deploy /apps/central
sudo chown -R deploy:deploy /var/log/central

# We found on a faster server if we started up the app really quickly it would generate
# very high CPU load for no apparent reason, putting this in places solves it
# if you are using a lower end VPS you can likely remove it (we only needed it when
# we moved to a 5800X bare metal server, never had an issue while using a VPS).
echo "Sleeping"
sleep 5

echo "Starting service"
sudo systemctl restart central.service

