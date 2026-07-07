defmodule Teiserver.Support.LobbyHelpers do
  @moduledoc """
  Utilities to construct lobbies with some sane defaults
  """

  alias Teiserver.TachyonLobby.Types, as: LT

  def mk_start_params(teams, user_id \\ "1234") do
    %LT.StartParams{
      creator_data: %{id: user_id, name: "name-#{user_id}"},
      creator_pid: self(),
      name: "test create lobby",
      map_name: "irrelevant map name",
      game_version: "fake game version",
      engine_version: "fake engine version",
      ally_team_config:
        Enum.map(teams, fn max_team ->
          x = for _i <- 1..max_team, do: %{max_players: 1}

          %LT.AllyTeamConfig{
            max_teams: max_team,
            start_box: %{top: 0, left: 0, bottom: 1, right: 0.2},
            teams: x
          }
        end)
    }
  end
end
