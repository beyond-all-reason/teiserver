This is designed to be a basic overview on how to get Teiserver working in production. It is aimed at people who know how to use a terminal but might not be sure how to setup a server and want/need a bit more of a step by step guide. I've been using Debian or Ubuntu as my distro of choice but this should work with most linux distros. Obviously you'll need to tweak some commands to suit them. 

Unless otherwise stated at the start of the code block, all commands are intended to be executed on the server.

### Requirements
- A linux based host, we're using Debian 10 for our examples so you might need to tweak them
- More cores the better, memory usage is pretty low (actual stats to be added at a later date)
- A domain name pointing to the server IP address
- The ability to use the terminal and a terminal editor such as [vim](https://www.vim.org)

#### DNS
Before you start I suggest setting up the DNS to point towards your server. It'll take time to propagate so doing it first will make things smoother to start with. Different registrars will have different interfaces (and documentation for them) so I'll not go over that here. You will also need to create an email account for your server to use.

### Fresh install time
```bash
apt-get update
apt-get -y install htop git-core ca-certificates vim sudo curl vnstat sysstat procinfo build-essential net-tools geoip-bin libtinfo-dev aptitude lsb-release grc neofetch tcpdump
apt-get -y upgrade
apt-get -y autoremove

# Now we use aptitude, I found it better in a number of situations
aptitude update
aptitude upgrade -y

# Set timezone
dpkg-reconfigure tzdata
```

#### Create our user
We start by creating a user for running the deployments. Doing things as root is a bad practice!
```bash
adduser deploy
adduser deploy sudo
```

### SSH key
Locally you should now generate an SSH key pair. I've followed the instructions [here](http://sshkeychain.sourceforge.net/mirrors/SSH-with-Keys-HOWTO/SSH-with-Keys-HOWTO-4.html).
```bash
# LOCALLY
ssh-keygen
#> Generating public/private rsa1 key pair.
#> Enter file in which to save the key (/home/username/.ssh/identity): /home/username/.ssh/identity
#> Enter passphrase (empty for no passphrase):
#> Enter same passphrase again:
#> Your identification has been saved in /home/username/.ssh/identity.
#> Your public key has been saved in /home/username/.ssh/id_rsa.pub.
#> The key fingerprint is:
#> 22:bc:0b:fe:f5:06:1d:c0:05:ea:59:09:e3:07:8a:8c username@caprice

# That id_rsa.pub is the part we'll upload to our server and then refer to the non-pub file when we want to connect.

scp ~/.ssh/id_rsa.pub deploy@yourdomain.com:./id_rsa.pub
```

Now back on the server (logged in as `deploy`) we make use of this
```bash
cd ~
mkdir .ssh
chmod 700 .ssh
cd .ssh
touch authorized_keys
chmod 600 authorized_keys
cat ../id_rsa.pub >> authorized_keys
rm ../id_rsa.pub
exit
```

You should now be able to login to the server like so:
```bash
ssh -i ~/.ssh/identity deploy@yourdomain.com
```

From now on we will be proceeding under the assumption you are logged in as the deploy user.

### Nginx
Nginx is a webserver we'll be using to facilitate the webinterface portion of Teiserver. If you don't want to make use of the web interface you can skip this portion of the setup process. You will need to have your DNS setup ahead of this step or it will fail when you try to setup the SSL part.

```bash
sudo aptitude install -y nginx
sudo chown -R deploy:deploy /var/www/
sudo chmod +r /var/log/nginx

# Create your index.html file, be sure to replace yourdomain.com with your actual domain name
# All this index file will do is forward non-https visitors to the https version
# of your site whereupon Teiserver will handle the request
echo "<html><head><meta http-equiv=\"refresh\" content=\"0; url=https://yourdomain.com/\" /></head><body>You are being redirected to <a href=\"https://yourdomain.com/\">https://yourdomain.com/</a></body></html>" > /var/www/html/index.html
```

#### Update the Nginx conf file
The template file is located in [documents/prod_files/nginx.conf](/documents/prod_files/nginx.conf), you will need to replace the existing nginx conf with it's contents.
```bash
sudo rm /etc/nginx/nginx.conf
sudo vi /etc/nginx/nginx.conf
```

#### Process limits for nginx
```
sudo mkdir -p /etc/systemd/system/nginx.service.d
sudo vi /etc/systemd/system/nginx.service.d/override.conf

# Put this in the file
[Service]
LimitNOFILE=65536

# Run this to reload and restart it
sudo systemctl daemon-reload
sudo systemctl restart nginx

# Use this to verify the limit has been increased
cat /proc/<nginx-pid>/limits
```

### SSL time
We'll be using [letsencrypt](https://letsencrypt.org/) to get a free SSL certificate.
```bash
# This is a Debian version specific command, be sure to check the letsencrypt documentation
sudo aptitude -y install snapd
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo certbot --nginx -d yourdomain.com -m your@email.com --agree-tos

# This will place your certs in /etc/letsencrypt/live/yourdomain.com
# We'll point the site directly here but also the TLS instance of ranch
# As a result we'll need to tweak the permissions
sudo chmod -R 0755 /etc/letsencrypt/{live,archive}

# Lets make sure everything is hunky-dory
sudo certbot renew --dry-run

# Now we create our dh file used for ciphers
mkdir -p /var/www/tls
sudo chown -R deploy:deploy /var/www/tls
chmod -R o+r /var/www/tls

cd /var/www/tls/
openssl dhparam -out dh-params.pem 2048
```

#### Enable the site
Has to be done after the cert!
```bash
sudo vi /etc/nginx/sites-enabled/central
```


### Postgres
This is written with postgres 14 as the intended version. If you need this guide to tell you how to install postgres you probably don't care if there's a newer version available.
```bash
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo aptitude update
sudo aptitude -y install postgresql-14
```

#### Setup teiserver_prod database
You will need to replace the `---------` with a new password, the same one you will place in your `config/prod.secret.exs`.

```bash
sudo su postgres
psql postgres postgres <<EOF
CREATE USER teiserver_prod WITH PASSWORD '---------';
CREATE DATABASE teiserver_prod;
GRANT ALL PRIVILEGES ON DATABASE teiserver_prod to teiserver_prod;
ALTER USER teiserver_prod WITH SUPERUSER;
EOF
```


#### pg_stat_statements (optional)
Following the guide at [pganalyze.com](https://pganalyze.com/docs/install/01_enabling_pg_stat_statements) we want to enable `pg_stat_statements` for our LiveDashboard. If we don't then that's okay but we won't get the full gamut of stats in the dashboard.
```bash
sudo vi /etc/postgresql/14/main/postgresql.conf
```

Add the following at various points:
```bash
shared_preload_libraries = 'pg_stat_statements'

# Increase the max size of the query strings Postgres records
track_activity_query_size = 2048

# Track statements generated by stored procedures as well
pg_stat_statements.track = all
```

#### pg_hba.conf (optional)
I've found it useful in the past to be able to access my postgres installation without having to put the password in. You may wish to update your pg_hba.conf to enable the same.

```bash
sudo vi /etc/postgresql/14/main/pg_hba.conf
```

Alter the bottom part to look like this, the specific change is we are using "trust" as the method for all local/host connections:
```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
```

#### External connections
If you are using clustering or hosting your postgres on a different box you will need to also enable external connections to your postgres install. You will need to perform additional edits to your pg_hba.conf

```bash
sudo vi /etc/postgresql/14/main/postgresql.conf
```

Add in the line
```
listen_addresses = '*'
```

```bash
sudo vi /etc/postgresql/14/main/pg_hba.conf
```

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    all             all             0.0.0.0/0               md5
```

#### Restart postgres
`sudo service postgresql restart`

You can test the changes using `psql -U teiserver_prod` from the deploy user. If you connect to the database it's worked, if you get a permissions error it has not.


### Setting up some files and directories
For this example I've put lots of stuff in the root directory. Feel free to relocate things.
```bash
cd /

# This is the directory it'll run from, we need it to exist or you'll get misleading errors
sudo mkdir -p /etc/central
sudo chown -R deploy:deploy /etc/central

# This is where the app itself will live
sudo mkdir -p /apps/central
sudo chown -R deploy:deploy /apps

# A bunch of bash scripts we'll use
sudo mkdir -p /scripts 
sudo chown -R deploy:deploy /scripts

# The location of our app logs
sudo mkdir -p /var/log/central
sudo chmod -R o+wr /var/log/central

# This is where we'll be uploading the release tarballs to
sudo mkdir -p /releases
sudo chmod -R o+wr /releases
```

#### grc
I use grc for my log colours so the aliases in .bashrc use it. If you don't want to use grc you'll need to update these. If you do want to use it you will also need to place the contents of [documents/prod_files/grc_log_colours](/documents/prod_files/grc_log_colours) in `/usr/share/grc/elixir.log`.

#### bashrc
Append to `~/.bashrc` the contents of [documents/prod_files/bashrc.sh](/documents/prod_files/bashrc.sh). This contains a bunch of commands to make life easier for you; especially if like me you can't always recall exactly where logs and the like are!

#### scripts
Now we have a .bashrc file pointing to them, we need to add some scripts to help manage our system. For each of the scripts referenced here, create a copy of them in the `/scripts` directory of your server.


#### Service file
The central.service file is located [documents/prod_files/central.service](/documents/prod_files/central.service)
```
# Edit/insert the file here
sudo vi /etc/systemd/system/central.service

# Now enable it
sudo systemctl enable central.service
```

#### File descriptors limit
ranch will make heavy use of your file descriptors. By default the level is quite low and I'd advise upping it. There are a _lot_ of pages on how to do this and most of them didn't have the desired effect for me. I found I needed to do the following:
```bash
sudo vi /etc/security/limits.conf
--- Add this ---
root             soft    nofile          64000
root             hard    nofile          64000
deploy           soft    nofile          64000
deploy           hard    nofile          64000
----------------

sudo vi /etc/sysctl.conf
# Add the following
--- Add this ---
fs.file-max = 64000
----------------

sudo vi /etc/pam.d/common-session
--- Add this ---
session required  pam_limits.so
----------------

sudo vi /etc/pam.d/common-session-noninteractive
--- Add this ---
session required  pam_limits.so
----------------

sudo vi /etc/systemd/user.conf
--- Add this ---
DefaultLimitNOFILE=65535
----------------
```

### Database migrations
Once the app is deployed you should be able to run migrations like so. I've not had a chance to test if this works on a fresh install; it is possible the fresh install would have startup errors due to some tables being missing.
```
centralapp eval "Central.Release.migrate"
```

### Deployment
[Deployment itself is located in a different file.](/documents/guides/deployment.md), you will need to execute a deployment as part of the setup. There will be additional steps to take after your first deployment.

#### Creating the first user
To create your first root user make a note of `config :central, Central.Setup, key:` within `config/prod_secret.exs` as you will need that value here. Go to `https://domain.com/initial_setup/$KEY` where `$KEY` is replaced with the value in this config. This link will only work while a user with an email "root@localhost" has not been created. It is advised that once the user is created you set the initial_setup key to be an empty string which will disable the function entirely.

A new user with developer level access will be created with the email `root@localhost` and a password identical to the setup key you just used. You can now login as that user, it is advised your first action should be to change/update the password and set the user details (name/email) to the ones you intend to use as admin.

### Usage stats
One of the packages you installed at the start is sysstat. It can be configured to track the CPU, memory etc stats of the server.
```sudo vi /etc/default/sysstat```

Change `ENABLED="false"` to `ENABLED="true"`.

There's also a script I use to automatically download the output and open a firefox browser to something which can build nice graphs out of it.

```bash
#!/usr/bin/env bash

# Generate file
ssh -i  ~/.ssh/identity deploy@yourdomain.com <<'ENDSSH'
  ls /var/log/sysstat/sa?? | xargs -i sar -A -f {} > /tmp/sar_teiserver.txt
ENDSSH

# Download the file
scp -i  ~/.ssh/identity deploy@yourdomain.com:/tmp/sar_teiserver.txt ~/Downloads/sar.txt

# Linux mint file manager, on Mac you can use "open" and other linux distros have their own file managers
nemo ~/Downloads

# Replace with browser of choice
firefox --new-tab "https://sarchart.dotsuresh.com/"
```

### Favicon
At some stage you'll probably want to do these things, no rush though.
- Upload a favicon to `/var/www`
`scp -i ~/.ssh/identity favicon.ico deploy@yourdomain.com:/var/www/`

### Backups
This is a script I run locally to create and get the backup.

```bash
#!/usr/bin/env bash

# Cause backup to be created
ssh -i ~/.ssh/identity deploy@yourdomain.com <<'ENDSSH'
  pg_dump --username=teiserver_prod --dbname=teiserver_prod --file=/tmp/backup.db
  echo 'Backup created'
ENDSSH

# Download the file
scp -i ~/.ssh/identity deploy@yourdomain.com:/tmp/backup.db ~/teiserever_backups/teiserver.db
echo 'Backup downloaded'

# Now delete the remote backup
ssh -i ~/.ssh/identity deploy@yourdomain.com <<'ENDSSH'
  rm /tmp/backup.db
  echo 'Remote backup removed'
ENDSSH
```

## Debugging a bad setup
#### Need more swap
```bash
#- Make the swap file: 1 minute, creates 8GB swap
cd /var
sudo touch swap.img
sudo chmod 600 swap.img
sudo dd if=/dev/zero of=/var/swap.img bs=1024k count=8000
sudo mkswap /var/swap.img
sudo swapon /var/swap.img
sudo su -c "echo '/var/swap.img swap swap defaults 0 0' >> /etc/fstab"
sudo sysctl vm.swappiness=10
sudo su -c "echo 'vm.swappiness=10' >> /etc/sysctl.conf"
```

#### Website not working
Ensure the service is running, the logs should be empty
```
sudo systemctl status central
sudo journalctl -u central.server
```

- `curl http://localhost:8888` should produce `curl: (1) Received HTTP/0.9 when not allowed`
- `curl https://localhost:8888` should produce an error starting with `curl: (60) SSL: no alternative certificate subject name matches target host name 'localhost'`
- `curl --insecure https://localhost:8888` should produce a web page similar to `curl http://localhost:4000`

- `curl http://localhost:4000` should produce a web page
- `curl https://localhost:4000` should produce `curl: (35) error:1408F10B:SSL routines:ssl3_get_record:wrong version number`

- `curl curl http://localhost:443` should give a 400 result

- `openssl s_client localhost:443` should give an SSL certificate info, this is nginx
- `openssl s_client localhost:8888` should give the same info, this is the Phoenix application

#### Nginx
Looking at logs for nginx with this
```
sudo systemctl status nginx
journalctl -u nginx.server
```

**Possible SSL related errors:**
- Certbot files not existing
- Certbot files not having the right permissions (try to `cat` them)
- Certs not being referenced by the application (used `Application.get_env(:central, CentralWeb.Endpoint)[:https]` within the remote terminal to check the actual paths in the app) 

#### What is "central"?
I've a few different projects all of which rely on a common core of functionality (users, groups etc). This is stored as the "central" folder which makes it easier to share code and the like between them. It does mean the application launched is called "central" though. The main repo for Central is [https://github.com/Teifion/central](https://github.com/Teifion/central).