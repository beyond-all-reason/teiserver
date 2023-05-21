#### teiserver_lobby_chat:#{battle_lobby_id}
Information specific to the chat in a battle lobby, state changes to the battle are not sent via this channel.
```elixir
%{
  event: :say,
  lobby_id: lobby_id,
  userid: user_id,
  message: message
}

%{
  event: :announce,
  lobby_id: lobby_id,
  userid: user_id,
  message: message
}
```