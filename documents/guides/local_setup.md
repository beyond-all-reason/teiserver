# Local setup

This guide should contain all the necessary steps for setting up Teiserver locally.

## Using mise

You can use [mise](https://mise.jdx.dev/dev-tools/) to automatically manage the
dependencies and application tasks, this method streamlines the development
setup.

Run `mise setup`.

This should:

- Configure a local postgres installation at `tmp/postgres` that can be managed
with `mise pg:start` and `mise pg:stop`.
- Set up the encryption certificates.
- Create and migrate the development and test databases for teiserver.

## Manual setup

### Install services

You will need to install:

- [Elixir + Erlang](https://elixir-lang.org/install.html).
- [PostgreSQL](https://www.postgresql.org/download).

Make sure that you have the correct version of Elixir (currently using 1.19.4) and Erlang OTP (currently 26.2.5.14). You can find the dependency requirement [here](https://github.com/beyond-all-reason/teiserver/blob/master/mix.exs#L8).

> [!TIP]
> You can use [asdf](https://github.com/asdf-vm/asdf) to install the correct version, it will be picked up from the file `.tool-versions`.

### Install build tools (gcc, g++, make) and cryptographic libraries

#### Ubuntu/Debian

```bash
sudo apt update
sudo apt install build-essential libssl-dev
```

### Elixir setup

Download and compile the dependencies:

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
ALTER USER teiserver_dev WITH SUPERUSER;

CREATE USER teiserver_test WITH PASSWORD '123456789';
ALTER USER teiserver_test WITH SUPERUSER;
EOF
exit

# You should now be back in the teiserver folder as yourself
# this next command will create the required database.
# Set the MIX_ENV environment variable to perform tasks in a different mix
# environment (e.g. `MIX_ENV=test`).
mix ecto.create

# This next command will run all pending db migrations.
mix ecto.migrate
```

### Localhost certs

To run the TLS server locally you will also need to create localhost certificates in `priv/certs` using the following commands

```bash
cd priv/certs
openssl dhparam -out dh-params.pem 2048
openssl req -x509 -out localhost.crt -keyout localhost.key \
  -newkey rsa:2048 -nodes -sha256 \
  -subj '/CN=localhost' -extensions EXT -config <( \
   printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")
cd ../..
```

### SASS

We use sass for our CSS generation and you'll need to run this to get it started.

```bash
mix sass.install
```

## What's next?

You should now be ready to start developing Teiserver!<br> Check out the [development guide](/documents/guides/development.md) to help you with getting started.
