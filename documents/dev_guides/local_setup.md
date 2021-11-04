This is still a work in progress but loosely the sequence of steps you will need to take to setup a Teiserver is:

## Local/Dev
### Install services
You will need to install:
- [Elixir/Erlang installed](https://elixir-lang.org/install.html).
- [Postresql](https://www.postgresql.org/download).

### Clone repo
```
git clone git@github.com:beyond-all-reason/teiserver.git
cd teiserver
```

### Install build tools (gcc, g++, make)
#### Ubuntu/Debian
```
sudo apt update
sudo apt install build-essential
```

### Elixir/Node setup
```
mix deps.get
mix deps.compile
cd assets && npm install && node node_modules/webpack/bin/webpack.js --mode development
cd ..
```

### Postgres setup
If you want to change the username or password then you will need to update the relevant files in [config](/config).
```
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
mix.create
```

#### Localhost certs
To run the TLS server locally you will also need to create localhost certificates in `priv/certs` using the following commands

```
mkdir -p priv/certs
cd priv/certs
openssl dhparam -out dh-params.pem 2048
openssl req -x509 -out localhost.crt -keyout localhost.key \
  -newkey rsa:2048 -nodes -sha256 \
  -subj '/CN=localhost' -extensions EXT -config <( \
   printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")
cd ../..
```

#### Migrations
Run the following from your directory to migrate the database.
```
mix ecto.migrate
```

### Running it
```
mix phx.server
```
If all goes to plan you should be able to access your site locally at [http://localhost:4000/](http://localhost:4000/).

### Libraries you need to get yourself
The site makes liberal use of [FontAwesome](https://fontawesome.com/) so if you are using the site you'll need to download it and place the `all.min.js` file in `assets/static/js/fontawesome.js`.

If you want to use the blog you will also need to place [ace.js](https://ace.c9.io/) folder in the same place.

### Configuration
Most of the configuration takes place in [config/config.exs](config/config.exs) with the other config files overriding for specific environments. The first block of `config.exs` contains a bunch of keys and values, which you can update.

### Connecting to the spring party of your server locally
```
telnet localhost 8200
openssl s_client -connect localhost:8201
```

### Main 3rd party dependencies
The main dependencies of the project are:
- [Phoenix framework](https://www.phoenixframework.org/), a web framework with a role similar to Django or Rails.
- [Ecto](https://github.com/elixir-ecto/ecto), database ORM
- [Ranch](https://github.com/ninenines/ranch), a tcp server
- [Oban](https://github.com/sorentwo/oban), a backend job processing framework.
