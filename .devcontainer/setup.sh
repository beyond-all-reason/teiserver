echo "Installing dependencies..."
mix deps.get

echo "Setting up database..."
mix ecto.create
mix ecto.migrate

echo "Loading test data..."
mix teiserver.fakedata
