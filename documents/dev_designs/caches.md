## Pre clustering-changes caches
- Site config
- Report restrictions
- Audit log types
- Permission sets
- Group type
- Umbrella group
- Player group
- Internal group
- Update group caches for above 3
- Quick items
- User config types
- ConCache.put(:lists, :clients, [])
- ConCache.put(:lists, :rooms, [])
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

#### Identify if even needed
- ConCache.put(:lists, :rooms, [])

#### Keep but will need work to cache based on state of cluster
- ConCache.put(:lists, :clients, [])
- ConCache.insert_new(:lists, :lobbies, [])}

#### Keep but should check if needs backend work
- Site config
- Report restrictions
- Audit log types
- Permission sets
- Group type
- Umbrella group
- Player group
- Internal group
- Update group caches for above 3
- Quick items
- User config types
- GenerateAchievement types

#### Keep - No race-conditions

#### Keep - Minor changes made to backend to race-conditions

#### Replace with Singleton GenServer
- ConCache.put(:id_counters, :battle, 1)
- Springids
- id_counters
- ConCache.put(:application_metadata_cache, "teiserver_partial_startup_completed", true)
- ConCache.put(:application_metadata_cache, "teiserver_day_metrics_today_last_time", nil)
- ConCache.put(:application_metadata_cache, "teiserver_day_metrics_today_cache", true)

#### Replace with non-precached version (cache on access/change)
- User list precache (active)
- Queue precache
- Telemetry event/property types
- User list precache (remaining)
