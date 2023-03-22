#!/usr/bin/env bash

export COMPOSE_ENV=prod

root=$(git rev-parse --show-toplevel)
bash $root/scripts/gen_prod_container_secrets.sh

echo \
"If there were any notifications above, solve them.

On a fresh server; in the root of the repo execute:
        COMPOSE_ENV=prod docker compose -f docker-compose.yaml --no-cache up -d

Tear down with:
        COMPOSE_ENV=prod docker compose -f docker-compose.yaml down

Update teiserver with:
        COMPOSE_ENV=prod docker compose up --no-deps --no-cache --force-recreate --build teiserver -d
"