Teiserver makes use of the Phoenix pubsub. This document is designed to list the different channels and how they are used.

Anything prefixed with "legacy" is something only present because of the nature of the spring protocol and is going to be removed as soon as we're able to.
Anything prefixed with "teiserver" is something added after the spring protocol was implemented and follows better practices with clearer documentation.

Teiserver channels always send a map as the object and include the channel name (as a string) under the `channel` key.





## Legacy
These items are due to be stripped out

#### room:#{room_name}
All updates about the room and content for the room. Likely to be kept as is and renamed as a teiserver channel due to its nature.

## Teiserver
#### account_hooks
Used for hooking into account related activities such as updating users.

Valid events
```elixir
  {:account_hooks, :create_user, user, :create}
  {:account_hooks, :update_user, user, :update}

  {:account_hooks, :create_report, report}
  {:account_hooks, :update_report, report, :create | :respond | :update}
```

#### legacy_user_updates:#{userid}
Information about a specific user such as friend related stuff.

#### legacy_all_client_updates
Overlaps with `legacy_all_user_updates` due to blurring of user vs client domain.
