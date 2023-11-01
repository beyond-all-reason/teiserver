# Setup folders
# vi /scripts/deploy.sh
echo "Starting release (no reboot)"
cd /
rm -r /apps/teiserver_release
mkdir -p /apps/teiserver_release
cd /apps/teiserver_release

echo "Decompressing"
tar mxfz /releases/teiserver.tar.gz

echo "Backup existing"
rm -rf /apps/teiserver_backup
mv /apps/teiserver /apps/teiserver_backup

echo "Stopping service"
/apps/teiserver_backup/bin/teiserver stop
# Lets see if this allows us to restart faster
# sudo systemctl stop clustering.service

echo "Remove existing binary"
sudo rm -rf /apps/teiserver

echo "Relocate binary"
cp -r opt/build/_build/prod/rel/teiserver /apps

echo "Rotate logs"
rm /var/log/teiserver/error_old.log
rm /var/log/teiserver/info_old.log

cp /var/log/teiserver/error.log /var/log/teiserver/error_old.log
cp /var/log/teiserver/info.log /var/log/teiserver/info_old.log

sudo chmod o+rw /apps/teiserver/releases/0.1.0/env.sh
cat /apps/ts.vars >> /apps/teiserver/releases/0.1.0/env.sh

echo "+Q 65536" >> /apps/teiserver/releases/0.1.0/vm.args

echo "Reset logs"
> /var/log/teiserver/error.log
> /var/log/teiserver/info.log

# Reset permissions
sudo chown -R deploy:deploy /apps/teiserver
sudo chown -R deploy:deploy /var/log/teiserver

# We found on a faster server if we started up the app really quickly it would generate
# very high CPU load for no apparent reason, putting this in places solves it
# if you are using a lower end VPS you can likely remove it (we only needed it when
# we moved to a 5800X bare metal server, never had an issue while using a VPS).
echo "Sleeping"
sleep 5

echo "Starting service"
sudo systemctl restart teiserver.service

