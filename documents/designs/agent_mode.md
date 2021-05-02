## Agent mode
Designed to be used to simulate a set of users using the server. Designed to aid both lobby and server development along with some testing. It can be enabled/disabled in the configuration file and turned on using the web interface in Teiserver -> Admin -> Tools -> Agent mode or via Iex with `Teiserver.agent_mode()`. If already started then it will have no impact.

If you click the web interface button you'll be taken to a liveview page showing logs of the agents in action.

## Agent clients
The agents act as clients and interact with the system the same way any other client would.

### Agent list
 * **battlehost** - Every tick will open a battle lobby if not already in one. If already in one and there are no players, will randomly decide to keep it open or close it down.
 