#### teiserver_telemetry
Used for broadcasting internal telemetry for consumers (such as admin dashboard)
```elixir
%{
  event: :data,
  data: %{
    client: map(),
    battle: map()
  }
}
```

#### teiserver_public_stats
Similar to the `teiserver_telemetry` channel but specifically limited to be public info.
```elixir
%{
  user_count: integer,
  player_count: integer,
  lobby_count: integer,
  in_progress_lobby_count: integer
}
```

#### telemetry_user_properties
```elixir
%{
  event: :upserted_property,
  userid: userid,
  property_type_id: property_type_id,
  property_type_name: property_type_name,
  value: value
}
```

#### teiserver_telemetry_client_events
Used for broadcasting specific client telemetry events as defined in Barserver.Telemetry. Does not broadcast anonymous events.
```elixir
%{
  userid: userid,
  event_type_name: string,
  event_value: any
}
```

#### teiserver_telemetry_client_properties
Used for broadcasting specific client telemetry property updates as defined in Barserver.Telemetry. Does not broadcast anonymous property updates.
```elixir
%{
  userid: userid,
  property_name: string,
  property_value: any
}
```

#### teiserver_telemetry_server_events
Used for broadcasting server event telemetry
```elixir
%{
  userid: userid,
  event_type_name: event_type_name,
  value: value
}
```

