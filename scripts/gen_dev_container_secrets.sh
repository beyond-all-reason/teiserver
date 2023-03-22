#!/usr/bin/env bash

root=$(git rev-parse --show-toplevel)
runtimeDir=$root/runtime/$COMPOSE_ENV
sharedBackendEnv=$runtimeDir/backend.env
teiserverEnv=$runtimeDir/teiserver.env
sharedFrontendEnv=$runtimeDir/frontend.env

mkdir -p $runtimeDir

if [[ ! -f $sharedBackendEnv ]]; then
  cat >$sharedBackendEnv <<-EOF
POSTGRES_USER=teiserver
POSTGRES_PASSWORD=$(head /dev/urandom -c 64 | basenc --base64 | head -c 64)
POSTGRES_DB=teiserver
EOF
fi

if [[ ! -f $teiserverEnv ]]; then
  cat >$teiserverEnv <<-EOF
WEB_KEY=$(head /dev/urandom -c 64 | basenc --base64 | head -c 64)
WEB_KEY_BASE=$(head /dev/urandom -c 64 | basenc --base64 | head -c 64)
ACCOUNT_GUARD_KEY=$(head /dev/urandom -c 64 | basenc --base64 | head -c 64)
EOF
fi

if [[ ! -f $sharedFrontendEnv ]]; then
  cat >$sharedFrontendEnv <<-EOF
DOMAIN_NAME=localhost
EOF
fi

mkdir -p $runtimeDir/tls
cd $runtimeDir/tls
if [[ ! -f $runtimeDir/tls/privkey.pem || ! -f $runtimeDir/tls/cert.pem  || ! -f $runtimeDir/tls/dhparam.pem ]]; then
  echo "Generating TLS certificate(s)"
  openssl req -x509 -newkey rsa:4096 -nodes -keyout privkey.pem -out cert.pem -sha256 -days 365 \
    -subj '/CN=localhost' -extensions EXT -config <( \
      printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth"
    )

  cp cert.pem fullchain.pem

  openssl dhparam -out dhparam.pem 4096
fi