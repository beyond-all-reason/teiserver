This is still a work in progress but loosely the sequence of steps you will need to take to setup a Teiserver is:

## Local/Dev
### Install services
You will need to install:
- [Elixir/Erlang installed](https://elixir-lang.org/install.html).
- [Postresql](https://www.postgresql.org/download).

Make sure that Elixir is in correct version (I'm currently using 1.14). You can find required version [here](https://github.com/beyond-all-reason/teiserver/blob/master/mix.exs#L8).
You can use [asdf](https://github.com/asdf-vm/asdf) to install correct version.

### Clone repo
```bash
git clone git@github.com:beyond-all-reason/teiserver.git
cd teiserver
```

### Install build tools (gcc, g++, make)
#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install build-essential
```

### Elixir setup
```bash
mix deps.get
mix deps.compile
```

### Postgres setup
If you want to change the username or password then you will need to update the relevant files in [config](/config).
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

# You should now be back in the teiserver folder as yourself
# this next command will perform database migrations
mix ecto.create
```

#### Localhost certs
To run the TLS server locally you will also need to create localhost certificates in `priv/certs` using the following commands

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

### SASS
We use sass for our css generation and you'll need to run this to get it started.
```bash
mix sass.install
```

### Running it
Standard mode
```bash
mix phx.server
```

Interactive REPL mode
```
iex -S mix phx.server
```
If all goes to plan you should be able to access your site locally at [http://localhost:4000/](http://localhost:4000/).

### Libraries you need to get yourself
The site makes liberal use of [FontAwesome](https://fontawesome.com/) so if you are using the site you'll need to download it and do the following
```bash
fontawesome/css/all.css -> priv/static/css/fontawesome.css
fontawesome/webfonts -> priv/static/webfonts
```

If you want to use the blog you will also need to place [ace.js](https://ace.c9.io/) folder in the same place.

### Configuration
Most of the configuration takes place in [config/config.exs](config/config.exs) with the other config files overriding for specific environments. The first block of `config.exs` contains a bunch of keys and values, which you can update.

### Connecting to the spring party of your server locally
```bash
telnet localhost 8200
openssl s_client -connect localhost:8201
```

### config/dev.secret.exs
If you want to do things like have a discord bot in development you don't want these details going into git. It is advisable to create a file `config/dev.secret.exs` where you can put these config details. I would suggest a file like so:
```elixir
import Config

config :teiserver, Teiserver,
  enable_discord_bridge: true

config :teiserver, DiscordBridgeBot,
  token: "------",
  bot_name: "Teiserver Bridge DEV",
  bridges: [
    {"---", "main"},
    {"---", "promote"},
    {"---", "moderation-reports"},
    {"---", "moderation-actions"}
  ]

# Comment the below block to enable background jobs to take place locally
config :teiserver, Oban,
  queues: false,
  crontab: false

```

### Fake data
Running this:
```bash
mix teiserver.fakedata
```

Will generate a large amount of fake data and setup a root account for you. The account will have full access to everything and the database will be populated with false data as if generated over a period of time to make development and testing easier.

### Resetting your user password
When running locally it's likely you won't want to connect the server to an email account, as such password resets need to be done a little differently.

Run your server with `iex -S mix phx.server` and then once it has started up use the following code to update your password.

```elixir
user = Teiserver.Repo.get_by(Teiserver.Account.User, email: "root@localhost")
Teiserver.Account.update_user(user, %{"password" => "password"})
```

### Main 3rd party dependencies
The main dependencies of the project are:
- [Phoenix framework](https://www.phoenixframework.org/), a web framework with a role similar to Django or Rails.
- [Ecto](https://github.com/elixir-ecto/ecto), database ORM
- [Ranch](https://github.com/ninenines/ranch), a tcp server
- [Oban](https://github.com/sorentwo/oban), a backend job processing framework.

### Next Steps
If you want to develop features that interact with the lobby, then you will need to [set up SPADS](/documents/guides/spads_install.md).