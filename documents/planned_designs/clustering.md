# Objective
Currently Teiserver runs on a single node, we would like to run it on multiple nodes.

## Known issues
- ETS (via ConCache) is node specific, we need to make changes propagate across the cluster


## Work items
#### Propagate data
Any time an ETS is updated this needs to be propagated. `Central.cache_put` and `Central.cache_delete` are two functions to help with this.

#### PID store
Various services place their PID into ETS, this should be changed to be a Registry.
