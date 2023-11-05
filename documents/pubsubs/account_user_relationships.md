account_user_relationships:#{user_id}

```elixir
%{
  event: :new_incoming_friend_request,
  userid: to_user_id,
  from_id: from_user_id
}
```

```elixir
%{
  event: :friend_deleted,
  userid: to_user_id,
  from_id: from_user_id
}
```