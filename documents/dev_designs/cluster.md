# Clustering

This document describe the clustering setup and architecture so that multiple
beam node running teiserver can act as one cluster.

## Running locally

Because teiserver binds on a bunch of ports, to run multiple node locally you
need to set them up to avoid conflicts.
For example

```bash
# first node is fine, just give it a name
iex --sname node1 -S mix phx.server

# setup for second node
TEI_SPRING_IS_DISABLED=true TEI_PORT=4002 TEI_METRICS_SERVER_PORT=4003 iex --sname node2 -S mix phx.server
```

## Architecture

It is essentially based on the ideas from [this talk](https://www.youtube.com/watch?v=hdBm4K-vvt0): "Waterpark: Transforming Healthcare with Distributed Actors". Here are the main concepts and where it deviates from the talk.

Each stateful process is replicated across multiple (all) nodes. One node is
marked as the primary and the others are replica. Every request to this process
is routed to the primary node. The primary process will then replicate its
changes across replicas. When replicas acknoledge the changes, the primary will
respond to the original request.

To find each node's role, we use [rendezvous hashing](https://en.wikipedia.org/wiki/Rendezvous_hashing).

```elixir
[primary | replicas] = Enum.sort_by(nodes, fn node ->
  :erlang.phash2({node, routing_key})
end)
```

This allow us to avoid a central registry or lock for nodes to agree on which
is the primary.

The cluster topology problem isn't addressed yet. We needs a solution that
guarantee strongly consistent topology across all nodes.

Stateful process need to be structured in a way where it's easy to alter state
based on a request from the primary, while avoiding any side effects like
sending messages to user or other process.
Event sourcing is a good way to achieve these goals.

