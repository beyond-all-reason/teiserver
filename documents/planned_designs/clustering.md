# Objective
Currently Teiserver runs on a single node, we would like to run it on multiple nodes.

## Summary of progress
##### Propagate data
- [X] **Stage 1:** Central module functions
- [X] **Stage 2:** Implement ClusterServer
- [X] **Stage 3:** Cache actions should use the new functions in `Central`

##### PID store
- [X] **Stage 1:** Change each server process to register it's `pid` with `Teiserver.ServerRegistry`.
- [X] **Stage 2:** Ensure on a running server each of the servers expected appears in the registry list
- [X] **Stage 3:** Update all `get_server_pid` functions to call the registry, test them
- [X] **Stage 4:** Remove the ETS table and calls to it

##### PubSub.broadcast
- [ ] **Stage 1:** Identify which pubsub messages need to include the sending `Node.self()` as part of their structure
- [ ] **Stage 2:** One message at a time, update the documentation and implementation of said message (both send and receive)
- [ ] **Stage 3:** Identify other things that need to be a singleton (e.g. lobby_id, spring_id)
- [ ] **Stage 4:** Add functionality for a node coming online after the others and being caught-up on state of caches

##### Less reliance on pre-caching
- [X] **Stage 1:** Identify pre-caches used
- [X] **Stage 2:** Add a `caches.md` documentation file
- [X] **Stage 3:** Decide which can be migrated away
- [ ] **Stage 4:** Might need to use cache_update rather than cache_put to help ensure consistency
- [ ] **Stage 5:** Migrate caches away

##### Per node processes
- [X] **Stage 1:** List each type of process we track.
- [ ] **Stage 2:** Find a good example of a per-node message vs a cluster-wide message and document how it should work
- [ ] **Stage 3:** Identify the changes that will need to be made to it and attempt implementing them
- [ ] **Stage 4:** Repeat for all other messages to node vs cluster processes

## Known issues
- ETS (via ConCache) is node specific, we need to make changes propagate across the cluster

## Work items
##### Propagate data
Any time an ETS is updated this needs to be propagated. `Central.cache_put` and `Central.cache_delete` are two functions to help with this.

##### PID store
Various services place their PID into ETS, this should be changed to be a Registry. Long term we might want to swap to a pool system and things being in a Registry will make this easier.

##### PubSub.broadcast
Currently we use `broadcast` but in some cases we might need to either include the node with the data or use `broadcast_local`. One example would be achievements, we don't want to double-count them.

Additionally we should change anything that would normally be send(pid) to instead either be `GenServer.cast` or a `PubSub.broadcast` to make it more explicit.

##### Less reliance on pre-caching
When taking place pre-caching is an opportunity for nodes to diverge in state (e.g. user list). Ideally this would be replaced by a solution not requiring a pre-cache. As a bonus this will improve startup time.

##### Per node processes
We can't have N processes for every process such as ConsulServer processes, these need to be placed on a single node and communicated with via PubSub. At the same time we do want to have 1 central process per node without overlapping actions, e.g. CoordinatorServer.

We can use Horde to run a process with a single name and have it automatically get pushed over to other nodes when the host node goes down. At the same time we can have a per-node process by not using the Swarm/Horde supervisor. PubSub will work across nodes and so we need to be mindful of it as per the above point.

## List/explanation of steps to take
##### Propagate data
- **Stage 1:** Central module to have a selection of functions for updating the cache, when called locally they should also broadcast to the cluster to perform the same action
- **Stage 2:** Implement a cluster server process which listens to the messages mentioned in Stage 1 and acts on ones from other nodes while discarding from it's own
- **Stage 3:** Aside from one-time build caches, all cache actions should use the new functions in `Central`

##### PID store
- **Stage 1:** Change each server process to register it's `pid` with `Teiserver.ServerRegistry`.
- **Stage 2:** Ensure on a running server each of the servers expected appears in the registry list.
  Use the code snippet `Registry.select(Teiserver.ServerRegistry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])`
- **Stage 3:** Update all `get_server_pid` functions to call the registry, test them
- **Stage 4:** Remove the ETS table and calls to it

##### PubSub.broadcast
Note: This ties in with the "Per node process" item.
- **Stage 1:** Identify which pubsub messages need to include the sending `Node.self()` as part of their structure. By default we should assume all items are global.
- **Stage 2:** One message at a time, update the documentation and implementation of said message (both send and receive)
- **Stage 3:** Identify other things that need to be a singleton, they probably need to be placed in a single GenServer instance rather than ETS. Investigation has found only two things that need to be singletons.
- - User SpringId
- - Lobby match_id
- **Stage 4:** Add functionality for a node coming online after the others and being caught-up on state of caches (e.g. client/lobby list)

##### Less reliance on pre-caching
- **Stage 1:** Identify pre-caches used
- **Stage 2:** Add a `caches.md` documentation file at [/documents/dev_designs/caches.md](/documents/dev_designs/caches.md) to document the different caches
- **Stage 3:** Decide which can be migrated away
- **Stage 4:** Might need to use cache_update rather than cache_put to help ensure consistency
- **Stage 5:** Migrate the caches away

##### Per node processes
- **Stage 1:** List each type of process we track.

- - List of per ID processes (1 per id in entire cluster):
- - - ConsulServer
- - - LobbyThrottleServer
- - - AccoladeChatServer
- - - QueueServer
- - List of singular processes (1 per node but written to not be cross-cluster):
- - - CoordinatorServer
- - - AccoldeBotServer
- - - AutomodServer
- - Processes that don't track their PIDs (need to be written to not be cross-cluster):
- - - TelemetryServer
- - - SpringTelemetryServer
- - - AchievementServer

- **Stage 2:** Find a good example of a per-node message vs a cluster-wide message and document how it should work
- **Stage 3:** Identify the changes that will need to be made to it and attempt implementing them
- **Stage 4:** Repeat for all other messages to node vs cluster processes

## Lessons learned
- Ensure when registering processes they have a unique key. I accidentally registered the LobbyThrottles without having the lobby_id be part of the key and as a result they didn't register correctly at first.
- The pubsub.md document was incredibly helpful in planning, more documents like it should be made
