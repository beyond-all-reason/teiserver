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
