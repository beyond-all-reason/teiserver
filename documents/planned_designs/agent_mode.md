## Agent mode
Designed to be used to simulate a set of users using the server. Designed to aid both lobby and server development along with some testing. It can be enabled/disabled in the configuration file via `config :central, Teiserver` option `enable_agent_mode: true`. When enabled it will be launched seconds after the server has started up. There is a liveview page in [http://localhost:4000/teiserver/admin/agent](http://localhost:4000/teiserver/admin/agent) allowing some control over them.

## Agent clients
The agents act as clients and interact with the system the same way any other client would. They are designed to allow for testing of the server and lobby clients by mimicking behaviour as organically as is easily feasible.

### Agent list
 * **idle** - Sits there and pings the server so it doesn't get disconnected.
 * **battlehost** - Every tick will open a battle lobby if not already in one. If already in one and there are no players, will randomly decide to keep it open or close it down.
 * **battlejoin** - Randomly joins/leaves lobbies
 * **in_and_out** - Logs in and logs out
 * **TODO chat** - Joins chat rooms and interacts based on the behaviour selected
 * **TODO friender** - Periodically adds friends of people in the `#friender` chat channel
 * **TODO unfriender** - Periodically removes all it's friends
 * **TODO queue** - Joins matchmaking queues; if it ends up joining a lobby it will leave the lobby
 * **TODO party** - Accepts invites to parties and later leaves them
 * **TODO partyhost** - Periodically sends party invites to friends; later leaves the party
 
### Control
The agents are controlled from [supervisor_agent_server.ex](lib/teiserver/agents/supervisor_agent_server.ex) in the `def handle_info(:begin, state) do` function. Here you can tweak which agents are started as per your needs.

