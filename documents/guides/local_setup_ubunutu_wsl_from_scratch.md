# Local Teiserver setup

Using WSL with Ubuntu 22.0.4 downloaded from the windows store

Installed git, curl, and unzip
```bash
sudo apt install git curl unzip
```
git and curl were already pre-installed with their latest available versions.

Installed [asdf](https://github.com/asdf-vm/asdf) for managing versinos of elixir and erlang:
```bash
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
```

Set up asdf in bashrc:
```bash
echo '
. "$HOME/.asdf/asdf.sh"
. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
```

Add asdf plugins for elixir and erlang:
```bash
asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
```

Install dependencies for erlang install:
```bash
sudo apt-get -y install build-essential autoconf m4 libncurses5-dev libwxgtk3.0-gtk3-dev libwxgtk-webview3.0-gtk3-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses-dev openjdk-11-jdk
```

Install elixir and erlang versions tracked in project (must be done from root of project)
```bash
asdf install
```

Get and compile local elixir dependencies (say yes to prompts for additional installs):
```bash
mix deps.get
mix deps.compile
```

Install postgres:
```bash
sudo apt install postgresql
```

Start postgres service:
```bash
sudo service postgresql start
```

Set up `teiserver_dev` and `teiserver_test` accounts:
```bash
sudo su postgres
psql postgres postgres <<EOF
CREATE USER teiserver_dev WITH PASSWORD '123456789';
CREATE DATABASE teiserver_dev;
GRANT ALL PRIVILEGES ON DATABASE teiserver_dev to teiserver_dev;
ALTER USER teiserver_dev WITH SUPERUSER;

CREATE USER teiserver_test WITH PASSWORD '123456789';
CREATE DATABASE teiserver_test;
GRANT ALL PRIVILEGES ON DATABASE teiserver_test to teiserver_test;
ALTER USER teiserver_test WITH SUPERUSER;
EOF
exit
```

Create the database schema for the teiserver application:
```bash
mix ecto.create
```
ecto.create docs: https://hexdocs.pm/ecto/Mix.Tasks.Ecto.Create.html
ecto_repos is configured in [config/config.exs][./config/config.exs]

Create some self signed SSL certs for the local server to run with
```bash
mkdir -p priv/certs
cd priv/certs
openssl dhparam -out dh-params.pem 2048
openssl req -x509 -out localhost.crt -keyout localhost.key \
  -newkey rsa:2048 -nodes -sha256 \
  -subj '/CN=localhost' -extensions EXT -config <( \
   printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")
cd ../..
```

Install `sass` for CSS generation
```bash
mix sass.install
```

Cretae fake data for the server to start with
```bash
mix teiserver.fakedata
```

Download [fontawesome 5](https://fontawesome.com/v5/download) data and place it in the expected locations:
```bash
curl -o font-awesome.zip https://use.fontawesome.com/releases/v6.5.1/fontawesome-free-6.5.1-web.zip
unzip font-awesome.zip
mv fontawesome-free-6.5.1-web/css/all.css priv/static/css/fontawesome.css
mv fontawesome-free-6.5.1-web/webfonts/ priv/static/webfonts
rm font-awesome.zip
rm -rf fontawesome-free-6.5.1-web
```
NOTE: This uses the free package of font awesome, so some of the icons on the website will be missing

Start the server locally
```bash
mix phx.server
```

Now you can view the website running at http://localhost:4000. There is a default account with email `root@localhost` and password: `password`