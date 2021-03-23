defmodule Teiserver.Startup do
  use CentralWeb, :startup

  def startup do
    add_permission_set("teiserver", "admin", ~w(account battle))
    add_permission_set("teiserver", "player", ~w(account verified))

    add_group_type("Bar team", %{fields: []})

    umbrella_id =
      case Central.Account.get_group(nil, search: [name: "BAR umbrella group"]) do
        nil ->
          {:ok, group} =
            Central.Account.create_group(%{
              "name" => "BAR umbrella group",
              "active" => true,
              "icon" => "fas fa-umbrella",
              "colour" => "#00AA66",
              "data" => %{}
            })

          group.id

        group ->
          group.id
      end

    group_id =
      case Central.Account.get_group(nil, search: [name: "BAR Users"]) do
        nil ->
          {:ok, group} =
            Central.Account.create_group(%{
              "name" => "BAR Users",
              "active" => true,
              "icon" => "fas fa-robot",
              "colour" => "#000000",
              "data" => %{},
              "super_group_id" => umbrella_id
            })

          group.id

        group ->
          group.id
      end

    ConCache.put(:application_metadata_cache, "bar_umbrella_group", umbrella_id)
    ConCache.put(:application_metadata_cache, "bar_user_group", group_id)

    # QuickAction.add_items([
    #   %{label: "Battles", icons: [Teiserver.BattleLib.icon(), :list], input: "s", method: "get", placeholder: "Search battle name", url: "/teiserver/battle", permissions: "teiserver"},
    # ])

    # add_user_config_type %{
    #   key: "metis.Hide readme",
    #   section: "Metis",
    #   type: "boolean",
    #   visible: false,
    #   permissions: ["metis"],
    #   description: "Hides the readme when starting an event",
    #   opts: [],
    #   default: false,
    # }

    ConCache.put(:lists, :clients, [])
    ConCache.put(:lists, :rooms, [])
    ConCache.insert_new(:lists, :battles, [])

    ConCache.put(:id_counters, :battle, 0)
    ConCache.put(:id_counters, :user, 0)

    Teiserver.User.pre_cache_users()
  end
end
