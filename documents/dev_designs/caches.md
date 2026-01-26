## Pre clustering-changes caches
- Site config types
- Report restrictions
- Audit log types
- Permission sets
- Group type
- Umbrella, Player and Internal groups
- Update group caches for above 3
- Quick items
- User config types
- ConCache.put(:lists, :clients, [])
- ConCache.insert_new(:lists, :lobbies, [])}
- ConCache.put(:id_counters, :battle, 1)
- User list precache (active)
- Queue precache
- Springids
- id_counters
- ConCache.put(:application_metadata_cache, "teiserver_partial_startup_completed", true)
- ConCache.put(:application_metadata_cache, "teiserver_day_metrics_today_last_time", nil)
- ConCache.put(:application_metadata_cache, "teiserver_day_metrics_today_cache", true)
- GenerateAchievement types
- Telemetry event/property types
- User list precache (remaining)

#### Keep but will need work to cache based on state of cluster
- ConCache.put(:lists, :clients, [])
- ConCache.insert_new(:lists, :lobbies, [])}

#### Keep - No race-conditions and no duplication (uses db/store not cache)
- Site config types
- Report restrictions
- Audit log types
- Group type
- Umbrella, Player and Internal groups (uses cache but it's built from a DB entry that won't change)
- Quick items
- User config types
- GenerateAchievement types

#### Keep - Changes needed to backend before clustering but otherwise can remain as they are
- Permission sets (needs to become a Teiserver.store system)
- Update group caches for new groups (only needs to be run if the groups don't already exist)

#### Replace with Singleton GenServer
##### Done
- ConCache.put(:id_counters, :battle, 1)
- Springids
- id_counters

##### Delete these as no longer needed
- ConCache.put(:application_metadata_cache, "teiserver_partial_startup_completed", true)
- ConCache.put(:application_metadata_cache, "teiserver_day_metrics_today_last_time", nil)
- ConCache.put(:application_metadata_cache, "teiserver_day_metrics_today_cache", true)

#### Replace with non-precached version (cache on access/change)
##### Done
- User list precache (active)
- User list precache (remaining)
- Telemetry event/property types

##### Yet to do
- Queue precache
