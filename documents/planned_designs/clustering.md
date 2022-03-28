# Objective
Currently Teiserver runs on a single node, we would like to run it on multiple nodes.

## Known issues
- ETS (via ConCache) is node specific, we need to make changes propagate across the cluster

## Work items
#### Propagate data
Any time an ETS is updated this needs to be propagated. `Central.cache_put` and `Central.cache_delete` are two functions to help with this.

#### PID store
Various services place their PID into ETS, this should be changed to be a Registry.

#### PubSub.broadcast
Currently we use `broadcast` but in some cases we might need to either include the node with the data or use `broadcast_local`. One example would be achievements, we don't want to double-count them.

#### Less reliance on pre-caching
When taking place pre-caching is an opportunity for nodes to diverge in state (e.g. user list). Ideally this would be replaced by a solution not requiring a pre-cache. As a bonus this will improve startup time.
- Identify pre-caches used
- Decide which can be migrated away
- Might need to use cache_update rather than cache_put to help ensure consistency

## Logging of progress
#### Propagate data


#### PID store
**teiserver_throttle_pids**


**teiserver_queue_pids**
**teiserver_consul_pids**
**teiserver_accolade_pids**





#### PubSub.broadcast


#### Less reliance on pre-caching

