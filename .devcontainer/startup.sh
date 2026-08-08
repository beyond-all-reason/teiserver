#!/bin/bash
set -e

LOG=/tmp/teiserver-setup.log

echo "Waiting for database..."
until pg_isready -h database -U teiserver_dev -q; do
  sleep 1
done

echo "Installing dependencies..."
mix deps.get

echo "Setting up database..."
mix ecto.create
mix ecto.migrate

cat > /etc/motd << 'MOTD'

  Teiserver Dev Container
  =======================

  Server:  http://localhost:4000
  Mail:    http://localhost:8025
  
  Login credentials:
    Email:    root@localhost
    Password: password

  Before pushing, run the lint and style checks CI does:
    $ MIX_ENV=test mix lint
  or use the "Run Linter" task from the VS Code command palette.
  For the full set (lint, tests and dialyzer), run:
    $ mix precommit

  GitHub:
  =======================
  This container comes with the GitHub CLI installed. Use $ gh auth login to authenticate.
  Make sure the remotes are configured to HTTPS (and not SSH) to avoid authentication issues.

MOTD

echo ""
echo "Starting server..."
exec mix phx.server
