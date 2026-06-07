#!/bin/bash
set -e

LOG=/tmp/teiserver-setup.log

cat > /etc/motd << 'MOTD'

  Teiserver Dev Container
  =======================

  Server is setting up in the background.
  This may take a few minutes on first run.

  Follow progress:
    tail -f /tmp/teiserver-setup.log

    
  Teiserver Dev Container
  =======================

  Server:  http://localhost:4000
  Mail:    http://localhost:8025

  Login credentials:
    Email:    root@localhost
    Password: password

  GitHub:
  =======================
  This container comes with the GitHub CLI installed. Use $ gh auth login to authenticate.
  Make sure the remotes are configured to HTTPS (and not SSH) to avoid authentication issues.
  After authentication, you can use git as normal.

MOTD

exec > >(tee -a "$LOG") 2>&1

echo "Waiting for database..."
until pg_isready -h database -U teiserver_dev -q; do
  sleep 1
done

echo "Installing dependencies..."
mix deps.get

echo "Setting up database..."
mix ecto.create
mix ecto.migrate

SETUP_MARKER=".devcontainer/.setup_complete"
if [ ! -f "$SETUP_MARKER" ]; then
  echo "Loading test data..."
  mix teiserver.fakedata
  touch "$SETUP_MARKER"
fi

cat > /etc/motd << 'MOTD'

  Teiserver Dev Container
  =======================

  Server:  http://localhost:4000
  Mail:    http://localhost:8025
  
  Login credentials:
    Email:    root@localhost
    Password: password

  GitHub:
  =======================
  This container comes with the GitHub CLI installed. Use $ gh auth login to authenticate.
  Make sure the remotes are configured to HTTPS (and not SSH) to avoid authentication issues.

MOTD

echo ""
echo "Setup complete! Starting server..."
exec mix phx.server
