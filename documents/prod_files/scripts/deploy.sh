# Performs the full deployment process based on the release tarball
# being situated in /app/central_release
# It will not remove the tarball so you can re-run the release if needed

# Setup folders
echo "Starting release"
cd /
rm -r /apps/central_release
mkdir -p /apps/central_release
cd /apps/central_release

echo "Decompressing"
tar mxfz /releases/teiserver.tar.gz

echo "Backup existing"
rm -rf /apps/central_backup
mv /apps/central /apps/central_backup

echo "Relocate binary"
cp -r opt/build/_build/prod/rel/central /apps

echo "Stopping service"
/apps/central_backup/bin/central stop

echo "Wipe logs"
> /var/log/central/error.log
> /var/log/central/info.log

# Reset permissions
sudo chown -R deploy:deploy /apps/central

echo "Starting service"
sudo systemctl start central.service
