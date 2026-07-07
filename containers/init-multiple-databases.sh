#!/bin/bash

# Adapted from https://github.com/mrts/docker-postgresql-multiple-databases/blob/master/create-multiple-postgresql-databases.sh

set -euo pipefail

function create_user_and_database() {
  local database=$1
  echo "  Creating user and database '$database'"
  echo "  using username $POSTGRES_USER"
  psql --username "$POSTGRES_USER" <<-EOSQL
    DO \$\$
    BEGIN
      IF EXISTS (SELECT FROM pg_user WHERE  usename = '$database') THEN
        RAISE NOTICE 'SKIP ROLE MAKER!';
      ELSE
        CREATE ROLE $database LOGIN PASSWORD '$POSTGRES_PASSWORD' SUPERUSER;
      END IF;
    END
    \$\$;
    CREATE DATABASE $database;
    GRANT ALL PRIVILEGES ON DATABASE $database TO $database;
EOSQL
}

create_user_and_database teiserver_dev
create_user_and_database teiserver_test
