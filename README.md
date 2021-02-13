# Teiserver
An Elixir implementation of Uberserver

## Setup and running
You will need to have [Elixir/Erlang installed](https://elixir-lang.org/install.html).

```
cd teiserver
mix deps.get
mix run --no-halt
```

By default it will listen on port 8200 for TCP and port 8202 for UDP (not used at this time).

### Structure
```
    Client <--> TcpServer <--> Protocol <--> Data store <--> Logic
                    ^                            |
                    |                            |
                    -----------------------------
```

## Code layout/placement
- lib/protocols contains the interface for the protocols, these will interface with the TCP server and transform the input into function calls, protocols also handle sending messages back to the client
- lib/data contains the main backend implementation and handling for logic. Ideally written in a protocol-free way

### Protocols
A protocol (currently just the one) interfaces between the sever state logic and the client as shown above in the structure section. Protocols have a few common functions as defined in their MDoc property but loosely are:
- **handle/3** When the server receives a message it will hand it to the handle function which will parse it and subsequently call do_handle
- **do_handle/3** Handles a specific command, it may deal with subsequent parsing and sending messages back but will not directly update any global state or broadcast messages via PubSub.
- **reply/3** Handles sending commands/information back to the client. The protocol will transform the data to suit the protocol as needed, it is not expected to be in a specific format already.

### Entry point
lib/teiserver/tcp_server.ex is the main tcp server which handles TCP messages, these are typically handled by a protocol. By setting a different protocol in the state of a TCP listener you can change which protocol it uses.

### Testing
Run as above (`mix run --no-halt`) and load up Chobby. Set Chobby's server to `localhost`. In my experience it's then fastest to restart Chobby and it will connect to your locally running instance. After you've finished you'll want to set the server back to `road-flag.bnr.la`.

You can login using the normal login command but it's much easier to login using `LI <username>` which is currently in place for testing purposes. If you are familiar with Elixir then starting it with `iex -S mix` will put it in console mode and you can execute commands through the modules there too.

### State
##### Users
Keyed to the name of the user, these represent users registered with the system.

##### Clients
Keyed to the name of the user, these represent the users currently logged in. Client contains both the PID of the client and a Module reference to the protocol in use.

##### Battles
Does what it says on the tin.

### Rough roadmap (very happy to change it up):
- Remaining Spring commands
- Persistent data store
- Permissions system
- More units tests
- End to end tests
- Locked/passworded chat rooms
- Periodically clean up empty chat rooms
- Logging certain actions (in particular mod actions)
- Benchmark suite
