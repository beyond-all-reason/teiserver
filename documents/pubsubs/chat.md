#### room_chat:#{room_name}
Chat messages related to the room.
```elixir
%{
  channel: "room_chat",
  event: :message_received,
  room_name: room_name,
  id: RoomMessage.id,
  content: Message contents,
  user_id: UserId
}
```
