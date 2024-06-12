#!/usr/bin/env bash
export COMPOSE_ENV=dev

function delete() {
  docker compose -f docker-compose.yaml \
    -f docker-compose.dev.yaml \
    down
}

root=$(git rev-parse --show-toplevel)
bash $root/scripts/gen_dev_container_secrets.sh

if [[ $1 == '-d' ]]; then
  delete
  exit
fi

docker compose \
  -f docker-compose.yaml \
  -f docker-compose.dev.yaml \
  up \
  --build \
  --pull always \
  --renew-anon-volumes \

docker compose -f docker-compose.yaml \
  -f docker-compose.dev.yaml \
  stop