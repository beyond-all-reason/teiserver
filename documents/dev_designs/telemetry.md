Telemetry events take two main forms: Simple and Complex.

Simple events only note they happened and are very small.
Complex events also add additional data in the form of a JSON blob and thus take up a lot more space.

Each form is present in the categories: Client, Anon, Lobby, Match and Server.

Client and Anon are events from the client application itself. Anon are non-logged in users and instead a unique hash is used to link events together.
Lobby is tracked by the server but refers to events specific to lobbies
Match events are from the game itself
Server events are everything else happening on the server

Properties are values tied to a userid or hash and when updated with a new value overwrite the old value. Events happen multiple times while properties always just have a "most recent value". Properties only come in the simple version of a string.