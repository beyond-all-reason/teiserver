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

Currently we use [`libcluster`](https://hex.pm/packages/libcluster) with [`libcluster_postgres`](https://github.com/supabase/libcluster_postgres) to handle much of the plumbing of our clustering.

We can list all other nodes with the `Node.list()` call:

```elixir
iex(node1@localhost)1> Node.list()
[:node2@localhost, :node3@localhost]

iex(node2@localhost)1> Node.list()
[:node1@localhost, :node3@localhost]

iex(node3@localhost)2> Node.list()
[:node2@localhost, :node1@localhost]
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
