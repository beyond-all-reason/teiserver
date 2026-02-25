#!/bin/bash
set -e

echo "Starting Teiserver development setup..."

if [ "${GENERATE_FAKE_DATA}" = "true" ]; then
  mix teiserver.fakedata
else
  echo "Running migrations..."
  mix ecto.migrate
  echo "Migrations complete"
fi


echo "Setting up tachyon clients..."
mix teiserver.tachyon_setup
echo "Tachyon setup complete"


echo "Setup complete! Starting Phoenix server..."
exec "$@"
