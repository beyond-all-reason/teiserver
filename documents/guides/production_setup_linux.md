This is designed to be a basic overview on how to get Teiserver working in production. It is aimed at people who know how to use a terminal but might not be sure how to setup a server and want/need a bit more of a step by step guide. I've been using Debian or Ubuntu as my distro of choice but this should work with most linux distros. Obviously you'll need to tweak some commands to suit them. 

Unless otherwise stated at the start of the code block, all commands are intended to be executed on the server.

### Requirements
- A linux based host
- More cores the better, memory usage is pretty low (actual stats to be added at a later date)
- A domain name pointing to the server IP address
- The ability to use the terminal and a terminal editor such as [vim](https://www.vim.org)

#### DNS
Before you start I suggest setting up the DNS to point towards your server. It'll take time to propogate so doing it first will make things smoother to start with. Different registrars will have different interfaces (and documentation for them) so I'll not go over that here. You will also need to create an email account for your server to use.

### Fresh install time
```
apt-get update
apt-get -y install htop git-core ca-certificates vim sudo curl vnstat sysstat procinfo build-essential net-tools geoip-bin
apt-get -y upgrade
apt-get -y autoremove

# Set timezone
sudo dpkg-reconfigure tzdata
```

#### Create our user
We start by creating a user for running the deployments. Doing things as root is a bad practice!
```
adduser deploy
adduser deploy sudo
```

### SSH key
Locally you should now generate an SSH key pair. I've followed the instructions [here](http://sshkeychain.sourceforge.net/mirrors/SSH-with-Keys-HOWTO/SSH-with-Keys-HOWTO-4.html).
```
# LOCALLY
ssh-keygen
> Generating public/private rsa1 key pair.
> Enter file in which to save the key (/home/username/.ssh/identity): /home/username/.ssh/identity
> Enter passphrase (empty for no passphrase):
> Enter same passphrase again:
> Your identification has been saved in /home/username/.ssh/identity.
> Your public key has been saved in /home/username/.ssh/identity.pub.
> The key fingerprint is:
> 22:bc:0b:fe:f5:06:1d:c0:05:ea:59:09:e3:07:8a:8c username@caprice

# That identity.pub is the part we'll upload to our server and then refer to the non-pub file when we want to connect.

scp ~/.ssh/identity.pub deploy@yourdomain.com:./identity.pub
```

Now back on the server we make use of this
```
cd ~
mkdir .ssh
chmod 700 .ssh
cd .ssh
touch authorized_keys
chmod 600 authorized_keys
cat ../identity.pub >> authorized_keys
rm ../identity.pub
exit
```

You should now be able to login to the server like so:
```
ssh -i ~/.ssh/identity deploy@yourdomain.com
```

From now on we will be proceeding under the assumption you are logged in as the deploy user.

### Nginx (optional)
Nginx is a webserver we'll be using to facilitate the webinterface portion of Teiserver. If you don't want to make use of the web interface you can skip this portion of the setup process. You will need to have your DNS setup ahead of this step or it will fail when you try to setup the SSL part.

```
sudo apt-get install -y nginx
sudo chown -R deploy:deploy /var/www/
sudo chmod +r /var/log/nginx

# Create your index.html file, be sure to replace yourdomain.com with your actual domain name
# All this index file will do is forward non-https visitors to the https version
# of your site whereupon Teiserver will handle the request
echo "<html><head><meta http-equiv=\"refresh\" content=\"0; url=https://yourdomain.com/\" /></head><body>You are being redirected to <a href=\"https://yourdomain.com/\">https://yourdomain.com/</a></body></html>" > /var/www/html/index.html
```

#### Update the Nginx conf file
The template file is located in [documents/prod/nginx.conf](/documents/prod/nginx.conf), you will need to replace the existing nginx conf with it's contents.
```
sudo rm /etc/nginx/nginx.conf
sudo vi /etc/nginx/nginx.conf
```

#### SSL time
We'll be using [letsencrypt](https://letsencrypt.org/) to get a free SSL certificate.
```
# This is a Debian version specific command, be sure to check the letsencrypt documentation
sudo apt-get install -y certbot python-certbot-nginx -t stretch-backports

# Domain: yourdomain.com
# Redirect: 2, redirect everything
sudo certbot --nginx

# This will place your certs in /etc/letsencrypt/live/yourdomain.com
# We'll point the site directly here but also the TLS instance of ranch
# As a result we'll need to tweak the permissions
sudo chmod 0755 /etc/letsencrypt/{live,archive}

# Lets make sure everything is hunky-dory
sudo certbot renew --dry-run

# Now we create our dh file used for ciphers
mkdir -p /var/www/tls
sudo chown -R deploy:deploy /var/www/tls
chmod -R o+r /var/www/tls

cd /var/www/tls/
openssl dhparam -out dh-params.pem 2048
```

### Postgres
This is written with postgres 12 as the intended version. If you need this guide to tell you how to install postgres you probably don't care if there's a newer version available.
```
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql-12
```

#### Setup central_prod database
You will need to replace the `---------` with a new password, the same one you will place in your `config/prod.secret.exs`.

```
sudo su postgres
psql postgres postgres <<EOF
CREATE USER teiserver_prod WITH PASSWORD '-------------';
CREATE DATABASE teiserver_prod;
GRANT ALL PRIVILEGES ON DATABASE teiserver_prod to teiserver_prod;
ALTER USER teiserver_prod WITH SUPERUSER;
EOF
```

#### pg_hba.conf (optional)
I've found it useful in the past to be able to access my postgres installation without having to put the password in. You may wish to update your pg_hba.conf to enable the same.

```
sudo vi /etc/postgresql/12/main/pg_hba.conf
```

Alter the bottom part to look like this, the specific change is we are using "trust" as the method for all local/host connections:
```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
```

These changes will take effect on restart and you'll know they work if you can access the database using `psql -U central_prod` from the deploy user.


### Elixir
Follow the distro specific instructions at [https://elixir-lang.org/install.html](https://elixir-lang.org/install.html). They're different enough for each distro I feel it worth linking there.

You can test if erlang and elixir are installed with the following:
```
$ iex
Erlang/OTP 23 [erts-11.1] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:1] [hipe]

Interactive Elixir (1.11.2) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> 

--------

$ erl
Erlang/OTP 23 [erts-11.1] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:1] [hipe]

Eshell V11.1  (abort with ^G)
1> 
```

If one of the above doesn't work then it's likely something went wrong.

### Setting up some files and directories
For this example I've put lots of stuff in the root directory. Feel free to relocate things.
```
cd /

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

#### bashrc
Append to `~/.bashrc` the contents of [documents/prod/bashrc.sh](/documents/prod/bashrc.sh). This contains a bunch of commands to make life easier for you; especially if like me you can't always recall exactly where logs and the like are!

#### scripts
Now we have a .bashrc file pointing to them, we need to add some scripts to help manage our system. For each of the scripts referenced here, create a copy of them in the `/scripts` directory of your server.


#### Service file
The central.service file is located [documents/prod/central.service](/documents/prod/central.service)
```
# Edit/insert the file here
sudo vi /etc/systemd/system/central.service

# Now enable it
sudo systemctl enable central.service
```

#### File descriptors limit
ranch will make heavy use of your file descriptors. By default the level is quite low and I'd advise upping it. There are a _lot_ of pages on how to do this and most of them didn't have the desired effect for me. I found I needed to do the following:
```
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
[Deployment itself is located in a different file.](/documents/guides/deployment.md)

### Things left for you to do at your leisure
At some stage you'll probably want to do these things, no rush though.
- Upload a favicon to `/var/www`

### Maintenance
I've made use of the following scripts to perform maintenance/backups as needed.


#### get_backup
```
#!/usr/bin/env bash

# Cause backup to be created
ssh -i ~/.ssh/identity deploy@yourdomain.com <<'ENDSSH'
  pg_dump --username=teiserver_prod --dbname=teiserver_prod --file=/tmp/backup.db
  echo 'Backup created'
ENDSSH

# Download the file
scp -i ~/.ssh/identity deploy@yourdomain.com:/tmp/backup.db ~/teiserever_backups/teiserver.db
echo 'Backup downloaded'

# Now delete the backup
ssh -i ~/.ssh/identity deploy@yourdomain.com <<'ENDSSH'
  rm /tmp/backup.db
  echo 'Remote backup removed'
ENDSSH
```

### Usage stats
One of the packages you installed at the start is sysstat. It can be configured to track the CPU, memory etc stats of the server.
```sudo vi /etc/default/sysstat```

Change `ENABLED="false"` to `ENABLED="true"`.

There's also a script I use to automatically download the output and open a firefox browser to something which can build nice graphs out of it.

```
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

### FAQ
#### What is "central"?
I've a few different projects all of which rely on a common core of functionality (users, groups etc). This is stored as the "central" folder which makes it easier to share code and the like between them. It does mean the application launched is called "central" though.
