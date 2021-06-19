## Tachyon
Tachyon is a protocol designed for a client-server architecture for computer games; it is able to facilitate player messaging/chatting, game rooms, matchmaking and other such things. It is not designed for in-game netcode, just everything surrounding your netcode. These documents are written with developers in mind, players and general users should never even need to know the name of the protocol, let alone how it works.

## Spring interop
Given the server is currently used primarily for the Spring protocol you will need to select the Tachyon protocol by sending the `TACHYON` command. Optionally for testing/interop you can send `TACHYON some_data` where `some_data` is the JSON -> Gzip -> Base64 data you would send via Tachyon normally. It will result in the system sending the result back as if you were using the Tachyon protocol. It will do so without swapping you to the Tachyon protocol; this is intended only to enable access to certain commands added only for Tachyon and not as a long term solution.

#### Pages
- [Getting started](getting_started.md)
- [Command overview](overview.md)
- [Types](types.md)
- [Listeners](listeners.md)

#### Command types
- [Auth](auth.md)
- [Battle](battle.md)
- [Clan](clan.md)
- [User](user.md)
- [Communication](communication.md)
- [Matchmaking](matchmaking.md)
- [System](system.md)
