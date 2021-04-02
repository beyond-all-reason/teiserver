# Turns the service off and on again (wiping logs in the process)
# without performing the deployment process
# I typically used this while testing things

echo "Stopping service"
sudo systemctl stop central.service

echo "Wipe logs"
> /var/log/central/error.log
> /var/log/central/info.log

echo "Starting service"
sudo systemctl start central.service
