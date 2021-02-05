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

## Code layout/placement
- lib/protocols contains implementations for specific protocols
- lib/teiserver contains the main program implementation

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


#### TODO
- Friend requests
- Full battle room testing
- Battle chat
- Periodically clean up empty chat rooms
- Logging certain actions (in particular mod actions)
- Automated tests
- Benchmark suite

