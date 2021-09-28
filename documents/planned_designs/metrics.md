## Telemetry
Teiserver specific telemetry is recorded every 60 seconds, this means it is possible for a user to log in and out and not be picked up but normal usage will show up fairly accurately. If you use the Live Dashboard you will be able to see several telemetry metrics every 10 seconds.

### Minute by minute
This is handled in [telemetry_server.ex](lib/teiserver/servers/telemetry_server.ex), specifically the `get_totals\1` function. It collects basic information about active battles and clients. These are stored in the database at a 1 minute resolution. The data structure used is:
```
{
  "client": {
    "player": list(),
    "spectator": list(),
    "lobby": list(),
    "menu": list(),
    "total": list()
  },
  "battle": {
    "total": integer(),
    "lobby": integer(),
    "in_progress": integer()
  }
}
```

### Day by day
These are built from the minute by minute logs each morning for the preceding day. Periodic cleanup of older minute by minute logs also takes place at this stage. This task is performed in [persist_telemetry_day_task.ex](lib/teiserver/telemetry/tasks/persist_telemetry_day_task.ex) and will result in a data structure such as this:

```
{
  # Average battle counts per segment
  "battles": {
    "in_progress": segment_list(),
    "lobby": segment_list(),
    "total": segment_list(),
  },

  # Daily totals
  "aggregates": {
    "stats": {
      "accounts_created": integer(),
      "unique_users": integer(),
      "unique_players": integer()
    },

    # Total number of minutes spent doing that across all players that day
    "minutes": {
      "player": integer(),
      "spectator": integer(),
      "lobby": integer(),
      "menu": integer(),
      "total": integer()
    }
  },

  # The number of minutes users (combined) spent in that state during the segment
  "user_counts": {
    "player": segment_list(),
    "spectator": segment_list(),
    "lobby": segment_list(),
    "menu": segment_list(),
    "total": segment_list()
  },

  # Per user minute counts for the day as a whole
  "minutes_per_user": {
    "total": user_map(),
    "player": user_map(),
    "spectator": user_map(),
    "lobby": user_map(),
    "menu": user_map()
  }
}
```
**segment_list** refers to the day broken up into segments (defaults to 24 segments of 60 minutes each) and the relevant statistic for that segment. For example the `battles -> lobby` metric would be a list showing the average number of battles active per-minute in each segment. Meanwhile `user_counts -> player` counts the number of combined player minutes during that segment.

**user_map** is a dictionary of the user ID and the amount of time that specific user is estimated to have spent in that state.

### Still to do
- Discrete number of battles that took place
- Clan battles
- Matchmaking metrics
- Tourney battles
- Lobby types
