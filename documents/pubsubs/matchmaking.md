#### teiserver_global_matchmaking
Used to communicate to all wait servers so groups can be added/removed from queues correctly.
```elixir
# A match has been found, stop these groups searching for now
%{
  event: :pause_search
  groups: [group_id]
}

# Match failed to start, these groups are to resume searching
%{
  event: :resume_search
  groups: [group_id]
}

# This can fire for both a match starting and a match being declined
%{
  event: :cancel_search
  groups: [group_id]
}
```

#### teiserver_queue:#{queue_id}
Sent from the queue wait server to update regarding it's status
Valid events
```elixir
%{
  event: :queue_periodic_update,
  queue_id: queue_id,
  buckets: map(),
  groups_map: map()
}

%{
  event: :queue_add_group,
  queue_id: queue_id
  group_id: group_id
}

%{
  event: :queue_remove_group,
  queue_id: queue_id
  group_id: group_id
}


%{
  event: :match_attempt,
  queue_id: queue_id,
  match_id: match_id
}

%{
  event: :match_made,
  queue_id: queue_id,
  lobby_id: lobby_id
}
```

#### teiserver_all_queues
Data for those watching all queues at the same time
Valid events
```elixir
  %{
    event: :all_queues_periodic_update,
    queue_id: queue_id,
    group_count: integer,
    mean_wait_time: number
  }
```