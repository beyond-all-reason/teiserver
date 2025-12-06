## Structure
```
                                    Client                                
                              (Chobby/Spring/SPADS)
                                      ^
                                      |
                                      v
                   Protocol ------> ranch --------> Protocol  ------------> Can message Client state
               (spring_out.ex)    (gen_tcp)     (spring_in.ex)
                      ^                               |
                      |                               |
                      |                               v
               Client State <--------------------- State
                 (Genserver)                  (ConCache/ETS)
                                                      ^
                                                      |
                                                      v
                                                   Storage
                                                (Ecto/Postgres)
```

## Roles
Protocol is split into an In and an Out module. Their sole purpose is to translate internal messages for the client, no state based logic should be present in them. Incomming commands can message the client state directly but cannot perform the update themselves.

## Code layout/placement
- lib/protocols contains the interface for the protocols, these will interface with the TCP server and transform the input into function calls, protocols also handle sending messages back to the client
- lib/data contains the main backend implementation and handling for logic. 

### Protocols
A protocol (currently just the one) interfaces between the server state logic and the client as shown above in the structure section. Protocols have a few common functions as defined in their MDoc property but loosely are:
- **handle/3** When the server receives a message it will hand it to the handle function which will parse it and subsequently call do_handle
- **do_handle/3** Handles a specific command, it may deal with subsequent parsing and sending messages back but will not directly update any global state or broadcast messages via PubSub.
- **reply/3** Handles sending commands/information back to the client. The protocol will transform the data to suit the protocol as needed, it is not expected to be in a specific format already.

### Entry point
lib/teiserver/tcp_server.ex is the main tcp server which handles TCP messages, these are typically handled by a protocol. By setting a different protocol in the state of a TCP listener you can change which protocol it uses.

### State
##### Users
Keyed to the id of the user, these represent users registered with the system. These will be persisted over restarts at a later date.

##### Clients
Keyed to the id of the user, these represent the users currently logged in. Client contains both the PID of the client and a Module reference to the protocol in use.

##### Battles
Teiserver.Battle is a context that groups Lobby and Match related functions from LobbyLib and MatchLib.

(Note that Chobby and SPADS use the term `Battle` for what is represented by a `Match` in Teiserver.)

##### Lobby
Lobby in teiserver is what you expect from a lobby, it's state handled by the LobbyServer genserver, managing things like name, player list, spectators, bots, map, modoptions and the current match.

#### Match
Match contains actual data for a specific in game match, stored in DB.
Match itself is created when the lobby is initialised and remains in an empty state until started by the MMS at which point it's filled based on lobby state at the time. After MatchMonitorServer informs a match is finished, a new empty one will be created again.


#### MatchMonitorServer
The lobbies don't connect to MatchMonitorServer (MMS) directly, instead SPADS sends messages to AutohostMonitor (managed by MMS) (either directly via DM or in the #autohosts room). MMS then updates the match state or logs events and messages.

#### Room
Room is a chat room, e.g. #main, #newbie, #autohosts