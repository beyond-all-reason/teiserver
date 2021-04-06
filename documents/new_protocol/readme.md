Currently a selection of notes and "things to keep in mind" when writing a new protocol
- Always use tabs as separators
- Use namespaces to categorise commands
- Have some way to easily distinguish if a command is Server -> Client or Client -> Server, don't just reuse the same command name
- Command specifications should have parameter types defined
- Have versioned documentation, if someone wants to implement an older version there should be documentation for it
- No bitparsing
- If there's anything remotely confusing like bitparsing, have example test data for people writing their own implementation
- Should not need to use a regex to parse commands (maybe specific arguments but never the command as a whole)

#### Index
- [battles](battles.md)
- [chats](chats.md)
- [users](users.md)
- [misc](misc.md)

#### Global messages
The main issue with the current spring protocol is it currently sends everybody messages about everybody; creating an O(n^2) problem. Currently the following commands are global in nature:
- User logged in
- User disconnected
- Client updated
- Update battle
- Add battle
- Close battle
- User join battle
- User left battle

These can be broadly split into user/client and battle.

#### Battles
This is simple, unless you're in a battle or actively watching the list of battles you don't need to hear anything about battles. It'll be far more efficient to request lists of battles and get updates about the specific battle. Regarding lists, they should be able to be filtered at the command level to reduce the amount of data sent over the wire.

#### Users
Also easy to solve; you only receive updates about your friends and people in the same battle/chat etc as yourself. As soon as someone leaves that common location you stop getting updates about them and even when you do you only get the relevant ones. This is easy to achieve with carefully named pubsub channels.
