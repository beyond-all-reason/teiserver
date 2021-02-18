defmodule Teiserver.Application do
  @moduledoc false
  def children() do
    [
      {Teiserver.TcpServer, []},
      concache_perm_sup(:id_counters),
      concache_perm_sup(:lists),
      concache_perm_sup(:users_lookup_name_with_id),
      concache_perm_sup(:users_lookup_id_with_name),
      concache_perm_sup(:users_lookup_id_with_email),
      concache_perm_sup(:users),
      concache_perm_sup(:clients),
      concache_perm_sup(:battles),
      concache_perm_sup(:rooms)
    ]
  end

  defp concache_perm_sup(name) do
    Supervisor.child_spec(
      {
        ConCache,
        [
          name: name,
          ttl_check_interval: false
        ]
      },
      id: {ConCache, name}
    )
  end

  def startup_sub_functions() do
    Teiserver.Startup.startup()

    ConCache.put(:lists, :clients, [])
    ConCache.put(:lists, :rooms, [])

    ConCache.put(:id_counters, :battle, 0)
    ConCache.put(:id_counters, :user, 0)

    Teiserver.TestData.create_users()
    Teiserver.TestData.create_clients()
    Teiserver.TestData.create_battles()

    Teiserver.Room.create_room(%{
      name: "main",
      topic: "main",
      author: "ChanServ",
      members: ["Addas"]
    })
    |> Teiserver.Room.add_room()
  end
end
