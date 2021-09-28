## Agent mode
Designed to be used to simulate a set of users using the server. Designed to aid both lobby and server development along with some testing. It can be enabled/disabled in the configuration file. When enabled it will be launched seconds after the server has started up. There is a liveview page in [http://localhost:4000/teiserver/admin/agent](http://localhost:4000/teiserver/admin/agent) allowing some control over them.

## Agent clients
The agents act as clients and interact with the system the same way any other client would.

### Agent list
 * **idle** - Sits there and pings the server so it doesn't get disconnected.
 * **battlehost** - Every tick will open a battle lobby if not already in one. If already in one and there are no players, will randomly decide to keep it open or close it down.
