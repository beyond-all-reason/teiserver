#### teiserver_server
Used for sending out global messages about server events.
```elixir
%{
  event: :stopping,
  node: node
}

%{
  event: :started,
  node: node
}
```

#### lobby_policy_internal:#{lobby_policy_id}
Used for internal communication around lobby_policies where something needs to be seen by all processes. These will all originate from the organiser.
```elixir
# Used to request a status update from all the agent nodes
%{
  event: :request_status_update
}

# Used to request a status update from all the agent nodes
%{
  event: :updated_policy,
  new_policy: LobbyPolicy
}

# Used to tell all bots of that policy to disconnect
%{
  event: :disconnect
}
```

#### lobby_policy_updates:#{lobby_policy_id}
Used by the bots to send updates to anything listening for them (organiser and liveviews).
```elixir
%{
  event: :disconnect
}
```
