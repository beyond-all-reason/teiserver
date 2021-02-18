defmodule Teiserver.Startup do
  use CentralWeb, :startup

  def startup do
    add_permission_set "teiserver", "admin", ~w(account battle)
    add_permission_set "teiserver", "player", ~w(account verified)

    add_group_type("Bar team", %{fields: []})

    QuickAction.add_items([
      %{label: "Battles", icons: [Teiserver.BattleLib.icon(), :list], input: "s", method: "get", placeholder: "Search battle name", url: "/teiserver/battle", permissions: "teiserver"},
    ])

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
  end
end
