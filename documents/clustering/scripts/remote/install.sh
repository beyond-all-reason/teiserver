#!/usr/bin/env bash
apt-get update
apt-get -y install htop git-core ca-certificates vim sudo curl vnstat sysstat procinfo build-essential net-tools geoip-bin libtinfo-dev aptitude lsb-release grc neofetch ssl-cert
apt-get -y upgrade
apt-get -y autoremove

### Nginx
sudo aptitude install -y nginx
sudo mkdir -p /var/www/
sudo chown -R deploy:deploy /var/www/
sudo chmod +r /var/log/nginx

# systemctl enable nginx
# systemctl start nginx

### Nginx config
> /etc/nginx/nginx.conf
cat >> /etc/nginx/nginx.conf << EOF
user nginx;
worker_processes 4;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
  worker_connections 1024;
}

http {
  log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

  access_log  /var/log/nginx/access.log  main;

  sendfile            on;
  tcp_nopush          on;
  tcp_nodelay         on;
  keepalive_timeout   65;
  types_hash_max_size 4096;

  include             /etc/nginx/mime.types;
  default_type        application/octet-stream;

  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;
  
  gzip on;
  gzip_disable 'msie6';
  
  include /etc/nginx/conf.d/*.conf;
  include /etc/nginx/sites-enabled/*;
}
EOF

# Enabled site
mkdir -p /etc/nginx/sites-enabled/
> /etc/nginx/sites-enabled/teiserver
cat >> /etc/nginx/sites-enabled/teiserver << EOF
upstream teiserver {
    server 127.0.0.1:8888;
}
EOF

# cat >> /etc/nginx/sites-enabled/clustering EOF
# upstream clustering {
#     server 127.0.0.1:8888;
# }
# # The following map statement is required
# # if you plan to support channels. See https://www.nginx.com/blog/websocket-nginx/
# map $http_upgrade $connection_upgrade {
#     default upgrade;
#     '' close;
# }
# server {
#     client_max_body_size 0;
#     listen 80 http;

#     # server_name yourdomain.com;

#     location = /favicon.ico {
#       alias /var/www/favicon.ico;
#     }

#     location / {
#         try_files $uri @proxy;
#     }

#     location @proxy {
#         include proxy_params;
#         proxy_redirect off;
#         proxy_pass https://clustering;
#         proxy_http_version 1.1;
#         proxy_headers_hash_max_size 512;

#         # The following two headers need to be set in order
#         # to keep the websocket connection open. Otherwise you'll see
#         # HTTP 400's being returned from websocket connections.
#         proxy_set_header Upgrade $http_upgrade;
#         proxy_set_header Connection $connection_upgrade;
#         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#     }
# }
# EOF

# We installed ssl-cert package so have a self-signed cert already
# /etc/ssl/certs/ssl-cert-snakeoil.pem
# /etc/ssl/private/ssl-cert-snakeoil.key

# Now we create our dh file used for ciphers
mkdir -p /var/www/tls
sudo chown -R deploy:deploy /var/www/tls
chmod -R o+r /var/www/tls

cd /var/www/tls/
if [ -f "/var/www/tls/dh-params.pem" ]; 
then
  # File exists, we do nothing
  echo "dh-params.pem exists"
else
  # No file, we generate it
  openssl dhparam -out dh-params.pem 2048
fi

# Postgres
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo aptitude update
sudo aptitude -y install postgresql-14

# Update postgres hba
sudo sed -i 's/local   all             all                                     peer/local   all             all                                     trust/g' /etc/postgresql/14/main/pg_hba.conf
sudo sed -i 's/host    all             all             127.0.0.1\/32            scram-sha-256/host    all             all             127.0.0.1\/32            trust/g' /etc/postgresql/14/main/pg_hba.conf
sudo sed -i 's/host    all             all             ::1\/128                 scram-sha-256/host    all             all             ::1\/128                 trust/g' /etc/postgresql/14/main/pg_hba.conf

# Restart service
sudo service postgresql restart

sudo su postgres -c "psql -c \"CREATE USER teiserver_prod WITH PASSWORD 'prod_pass';\""
sudo su postgres -c "psql -c \"CREATE DATABASE teiserver_prod;\""
sudo su postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE teiserver_prod to teiserver_prod;\""
sudo su postgres -c "psql -c \"ALTER USER teiserver_prod WITH SUPERUSER;\""

# This is the directory it'll run from, we need it to exist or you'll get misleading errors
cd /
sudo mkdir -p /etc/teiserver
sudo chown -R deploy:deploy /etc/teiserver

# This is where the app itself will live
sudo mkdir -p /apps/teiserver
sudo chown -R deploy:deploy /apps

# A bunch of bash scripts we'll use
sudo mkdir -p /scripts 
sudo chown -R deploy:deploy /scripts

# The location of our app logs
sudo mkdir -p /var/log/teiserver
sudo chmod -R o+wr /var/log/teiserver

# This is where we'll be uploading the release tarballs to
sudo mkdir -p /releases
sudo chmod -R o+wr /releases


# Systemd
sudo rm /etc/systemd/system/teiserver.service
sudo touch /etc/systemd/system/teiserver.service
sudo chmod -R o+wr /etc/systemd/system/teiserver.service
cat >> /etc/systemd/system/teiserver.service << EOF
[Unit]
Description=Clustering Elixir application
After=network.target

[Service]
User=root
WorkingDirectory=/apps/teiserver
ExecStart=/apps/teiserver/bin/teiserver start
ExecStop=/apps/teiserver/bin/teiserver stop
Restart=on-failure
RemainAfterExit=yes
RestartSec=5
SyslogIdentifier=teiserver

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable teiserver.service
sudo systemctl start teiserver.service

# # IP Tables
# iptables -P INPUT ACCEPT
# iptables -P OUTPUT ACCEPT
# iptables -P FORWARD ACCEPT
# iptables -F

# # Secure linux
# semanage port -a -t http_port_t -p tcp 8888
