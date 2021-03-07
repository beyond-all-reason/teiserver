defmodule Teiserver.Application do
  @moduledoc false
  def children() do
    children = [
      %{
        id: Teiserver.SSLTcpServer,
        start: {Teiserver.TcpServer, :start_link, [[ssl: true]]}
      },
      %{
        id: Teiserver.RawTcpServer,
        start: {Teiserver.TcpServer, :start_link, [[]]}
      },
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

    # Some stuff doesn't work with the tests
    # but we're not that fussed about having it automtically
    # tested
    children ++ [
      {Teiserver.HookServer, name: Teiserver.HookServer},
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
    ConCache.insert_new(:lists, :battles, [])

    ConCache.put(:id_counters, :battle, 0)
    ConCache.put(:id_counters, :user, 0)

    Teiserver.User.pre_cache_users()
    # Teiserver.TestData.create_battles()

    # Teiserver.Room.create_room(%{
    #   name: "main",
    #   topic: "main",
    #   author: "ChanServ",
    #   members: []
    # })
    # |> Teiserver.Room.add_room()
  end
end
