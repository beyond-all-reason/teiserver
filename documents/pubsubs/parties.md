#### teiserver_party:#{party_id}
Sent from the queue wait server to update regarding it's status
Valid events
```elixir
%{
  event: :updated_values,
  party_id: party_id,
  new_values: map
}

%{
  event: :closed,
  party_id: party_id,
  reason: string
}

%{
  event: :message,
  party_id: party_id,
  sender_id: userid,
  message: string
}
```

