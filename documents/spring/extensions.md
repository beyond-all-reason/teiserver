### Spring protocol extensions
Teiserver implements a collection of additional commands beyond the spring protocol.

> [!WARNING]
> Documentation is not up to date. Additional coammnds were added but aren't documented yet.

#### Differences
All extended commands have a namespaced structure and make use of tabs to separate arguments like so. They still make use of a space to separate the command from the first argument to aid in compatibility. This applies to responses too, the new `NO` response will use a tab to separate the command from the reason.
```
Command Arg1[tab]Arg2[tab]Arg3
```

#### `c.moderation.report_user`
Adds a report of bad behaviour for the user. Location type should be something like "lobby", "battle" to give context to where the report happened. Location ID should be the specific numerical instance of that location. As chat rooms currently use names if you want to submit a report for a chat room the advised format is "chat:room_name" or just "chat". If you do not have a location_id then instead put "nil".
```
c.moderation.report_user target_name location_type location_id reason
c.moderation.report_user user123 lobby 5 reason for report
c.moderation.report_user user123 chat_room nil reason for report
OK
NO cmd=c.moderation.report_user reason_for_failure
```

#### `c.battles.list_ids`
Sends a list of battle ids separated by tabs:
```
c.battles.list_ids
s.battles.id_list 1 2 3
```

#### `s.battle.update_lobby_title lobby_id lobby.name`
Indicates a lobby has a new title.
```
s.battle.update_lobby_title 123 My new and fancy name
```

#### `s.system.shutdown`
Sent to indicate the system is shutting down.
```
s.system.shutdown
```
