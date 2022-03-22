#!/usr/bin/env bash
# Upload public key
scp ~/.ssh/id_rsa.pub deploy@192.168.1.185:./identity.pub
scp ~/.ssh/id_rsa.pub deploy@192.168.1.220:./identity.pub
scp ~/.ssh/id_rsa.pub deploy@192.168.1.235:./identity.pub
scp ~/.ssh/id_rsa.pub deploy@192.168.1.209:./identity.pub

# Apply it
ssh deploy@192.168.1.185 <<'ENDSSH'
  mkdir -p .ssh
  chmod 700 .ssh
  cd .ssh
  touch authorized_keys
  chmod 600 authorized_keys
  cat ../identity.pub >> authorized_keys
  rm ../identity.pub
  
  hostnamectl set-hostname barcluster1
ENDSSH

ssh deploy@192.168.1.220 <<'ENDSSH'
  mkdir -p .ssh
  chmod 700 .ssh
  cd .ssh
  touch authorized_keys
  chmod 600 authorized_keys
  cat ../identity.pub >> authorized_keys
  rm ../identity.pub
  
  hostnamectl set-hostname barcluster2
ENDSSH

ssh deploy@192.168.1.235 <<'ENDSSH'
  mkdir -p .ssh
  chmod 700 .ssh
  cd .ssh
  touch authorized_keys
  chmod 600 authorized_keys
  cat ../identity.pub >> authorized_keys
  rm ../identity.pub
  
  hostnamectl set-hostname barcluster3
ENDSSH

ssh deploy@192.168.1.209 <<'ENDSSH'
  mkdir -p .ssh
  chmod 700 .ssh
  cd .ssh
  touch authorized_keys
  chmod 600 authorized_keys
  cat ../identity.pub >> authorized_keys
  rm ../identity.pub
  
  hostnamectl set-hostname barcluster4
ENDSSH
