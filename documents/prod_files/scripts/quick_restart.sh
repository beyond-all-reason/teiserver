# Turns the service off and on again (wiping logs in the process)
# without performing the deployment process
# I typically used this while testing things
# vi /scripts/quick_restart.sh

echo "Stopping service"
/apps/teiserver/bin/teiserver stop
sudo systemctl stop teiserver.service

echo "Rotate logs"
rm /var/log/teiserver/error_old.log
rm /var/log/teiserver/info_old.log

cp /var/log/teiserver/error.log /var/log/teiserver/error_old.log
cp /var/log/teiserver/info.log /var/log/teiserver/info_old.log

echo "Wipe logs"
> /var/log/teiserver/error.log
> /var/log/teiserver/info.log

# We found on a faster server if we started up the app really quickly it would generate
# very high CPU load for no apparent reason, putting this in places solves it
# if you are using a lower end VPS you can likely remove it (we only needed it when
# we moved to a 5800X bare metal server, never had an issue while using a VPS).
echo "Sleeping"
sleep 5

echo "Starting service"
sudo systemctl start teiserver.service
