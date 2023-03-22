#!/usr/bin/env bash

root=$(git rev-parse --show-toplevel)
runtimeDir=$root/runtime/$COMPOSE_ENV
sharedBackendEnv=$runtimeDir/backend.env
teiserverEnv=$runtimeDir/teiserver.env
sharedFrontendEnv=$runtimeDir/frontend.env

mkdir -p $runtimeDir

cat >$sharedBackendEnv <<-EOF
POSTGRES_USER=teiserver
POSTGRES_PASSWORD=$(head /dev/urandom -c 64 | basenc --base64 | head -c 64)
POSTGRES_DB=teiserver
EOF

## Try to be nice a bit
if [[ ! -f $sharedFrontendEnv ]]; then
  cat >$sharedFrontendEnv <<-EOF
DOMAIN_NAME=fill this in
EOF

echo "Make sure you set DOMAIN_NAME in $sharedFrontendEnv"
fi

cat >$teiserverEnv <<-EOF
WEB_KEY=$(head /dev/urandom -c 64 | basenc --base64 | head -c 64)
WEB_KEY_BASE=$(head /dev/urandom -c 64 | basenc --base64 | head -c 64)
ACCOUNT_GUARD_KEY=$(head /dev/urandom -c 64 | basenc --base64 | head -c 64)
EOF

mkdir -p $runtimeDir/tls
echo "Generating dhparams.. This may take some time..."
openssl dhparam -out $runtimeDir/tls/dhparam.pem 4096 2>&1 >/dev/null

if [[ ! -f $runtimeDir/tls/privkey.pem || ! -f $runtimeDir/tls/cert.pem || ! -f $runtimeDir/tls/fullchain.pem ]]; then
  echo \
"There do not appear to be any TLS certificates or keys available for teiserver or nginx.
Unless you've modified the docker-compose.prod.yaml to account for this, Be sure to copy your certbot live key &
certs to $runtimeDir/tls before starting the prod docker compose"
fi