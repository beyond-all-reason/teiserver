# Clustering

Clustering is having multiple BEAM nodes running and having them connected to each other. Being able to run multiple nodes locally at once is important for testing any clustered functionality.

### Firing up 3 nodes

We recommend firing up 3 nodes for most tests.

```sh
# node1
iex --sname node1@localhost -S mix phx.server

# node2
TEI_PORT=8889 TEI_HTTPS_PORT=8890 TEI_METRICS_SERVER_PORT=4003 TEI_SPRING_TCP_PORT=8220 TEI_SPRING_TLS_PORT=8221 TEI_ENABLE_EMAIL_INTEGRATION=false iex --sname node2@localhost -S mix app.start

# node3
TEI_PORT=8891 TEI_HTTPS_PORT=8892 TEI_METRICS_SERVER_PORT=4004 TEI_SPRING_TCP_PORT=8222 TEI_SPRING_TLS_PORT=8223 TEI_ENABLE_EMAIL_INTEGRATION=false iex --sname node3@localhost -S mix app.start
```

You can then access each web interface at http://localhost:4000, http://localhost:8889 and http://localhost:8891.

### Talking between nodes

Currently we use [`db_cluster`](https://hex.pm/packages/db_cluster) to create connectivity but this may well change.

We can list all other nodes with the `Node.list()` call:

```elixir
iex(node1@localhost)1> Node.list()
[:node2@localhost, :node3@localhost]

iex(node2@localhost)1> Node.list()
[:node1@localhost, :node3@localhost]

iex(node3@localhost)2> Node.list()
[:node2@localhost, :node1@localhost]
```

To see the list of nodes expected to exist you can use the `DBCluster` library.

TODO: Update db_cluster to use a better query format and not need the empty args parameter in the list call.

```elixir
iex(node3@localhost)1> DBCluster.list_cluster_members(%{})

  [
    %DBCluster.ClusterMember{
      __meta__: #Ecto.Schema.Metadata<:loaded, "db_cluster_members">,
      id: "0b3ab120-66c2-4686-b2a5-c811e032b500",
      host: "node2@localhost",
      inserted_at: ~U[2026-11-05 11:04:49Z],
      updated_at: ~U[2026-11-05 11:04:49Z]
    },
    %DBCluster.ClusterMember{
      __meta__: #Ecto.Schema.Metadata<:loaded, "db_cluster_members">,
      id: "d21a0cb9-7a37-4f29-9fdd-097412327ea3",
      host: "node1@localhost",
      inserted_at: ~U[2026-11-05 11:04:52Z],
      updated_at: ~U[2026-11-05 11:04:52Z]
    },
    %DBCluster.ClusterMember{
      __meta__: #Ecto.Schema.Metadata<:loaded, "db_cluster_members">,
      id: "99e0edfc-3308-4c49-9bcc-87668f3475cd",
      host: "node3@localhost",
      inserted_at: ~U[2026-11-05 11:06:28Z],
      updated_at: ~U[2026-11-05 11:06:28Z]
    }
  ]
```

### Disconnects

To test a node going offline, just close the process running that node with `Ctrl + c`:

```elixir
iex(node3@localhost)3>
BREAK: (a)bort (A)bort with dump (c)ontinue (p)roc info (i)nfo
       (l)oaded (v)ersion (k)ill (D)b-tables (d)istribution
^C[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
[os_mon] memory supervisor port (memsup): Erlang has closed

iex(node1@localhost)2> Node.list()
[:node2@localhost]
```

Note: Due to a bug in `DBCluster` you will see an error message regarding deletion in the other windows. We expect this to change soon.

