# Turns the service off and on again (wiping logs in the process)
# without performing the deployment process
# I typically used this while testing things

echo "Stopping service"
/apps/central/bin/central stop
sudo systemctl stop central.service

echo "Rotate logs"
rm /var/log/central/error_old.log
rm /var/log/central/info_old.log

cp /var/log/central/error.log /var/log/central/error_old.log
cp /var/log/central/info.log /var/log/central/info_old.log

echo "Wipe logs"
> /var/log/central/error.log
> /var/log/central/info.log

echo "Starting service"
sudo systemctl start central.service
