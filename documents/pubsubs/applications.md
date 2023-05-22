Channels for applications to get additional information

#### client_application:#{userid}
Designed for lobby applications to display/perform various actions as opposed to internal agent clients or any web interfaces
```elixir
  %{
    event: :ring,
    userid: userid,
    ringer_id: ringer_id
  }
```