#!/usr/bin/env bash
# Upload the install file
scp -i ~/.ssh/id_rsa documents/clustering/scripts/remote/install.sh deploy@192.168.1.185:install.sh
scp -i ~/.ssh/id_rsa documents/clustering/scripts/remote/install.sh deploy@192.168.1.220:install.sh
scp -i ~/.ssh/id_rsa documents/clustering/scripts/remote/install.sh deploy@192.168.1.235:install.sh
scp -i ~/.ssh/id_rsa documents/clustering/scripts/remote/install.sh deploy@192.168.1.209:install.sh

# and the bashrc
scp -i ~/.ssh/id_rsa documents/clustering/scripts/remote/bashrc deploy@192.168.1.185:.bashrc
scp -i ~/.ssh/id_rsa documents/clustering/scripts/remote/bashrc deploy@192.168.1.220:.bashrc
scp -i ~/.ssh/id_rsa documents/clustering/scripts/remote/bashrc deploy@192.168.1.235:.bashrc
scp -i ~/.ssh/id_rsa documents/clustering/scripts/remote/bashrc deploy@192.168.1.209:.bashrc

# Now run it
ssh deploy@192.168.1.185 <<'ENDSSH'
  echo "123456" | sudo -S sh install.sh
ENDSSH

ssh deploy@192.168.1.220 <<'ENDSSH'
  echo "123456" | sudo -S sh install.sh
ENDSSH

ssh deploy@192.168.1.235 <<'ENDSSH'
  echo "123456" | sudo -S sh install.sh
ENDSSH

ssh deploy@192.168.1.209 <<'ENDSSH'
  echo "123456" | sudo -S sh install.sh
ENDSSH

