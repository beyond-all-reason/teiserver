This is still a work in progress but loosely the sequence of steps you will need to take to setup a Teiserver is:

## Local/Dev
#### Elixir and Erlang
You will need to have [Elixir/Erlang installed](https://elixir-lang.org/install.html). 

#### Phoenix
Adapt the instructions for [installing phoenix](https://hexdocs.pm/phoenix/up_and_running.html) -- this is the bit I need to expand!

FontAwesome (only if you want to use the site)
Ace.js (if you want to use the blog)

#### Localhost certs
You will also need to create localhost certificates in `priv/certs` using the following commands

```
openssl req -x509 -out localhost.crt -keyout localhost.key \
  -newkey rsa:2048 -nodes -sha256 \
  -subj '/CN=localhost' -extensions EXT -config <( \
   printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")
mkdir priv/certs
mv localhost.crt priv/certs/localhost.crt
mv localhost.key priv/certs/localhost.key
```

#### Acutally running the server
At this stage you can now run the server
```
cd teiserver
mix deps.get
mix run --no-halt
```

By default it will listen on port 8200 for TCP and 8201 for TLS. You can connect to these with:

#### Connecting to your server
```
telnet localhost 8200
openssl s_client -connect localhost:8201
```

## Remote/Prod
- Not currently ready for production use
- several things are currently hard coded to BAR/Teifion specifics (such as emails)
- If you want to run this in prod please let me know and I'll put priority work into fixing this; at the current time I'm not aware of anybody else looking to use this in prod and as such it's not a priority
