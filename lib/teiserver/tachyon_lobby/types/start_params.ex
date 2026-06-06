defmodule Teiserver.TachyonLobby.Types.StartParams do
  @moduledoc """
  the parameters required to create a new lobby.
  It's enough data to generate the initial lobby internal state, which in
  turn can be used to start a battle
  """

  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:creator_data, :creator_pid, :name, :map_name, :ally_team_config]
  defstruct [
    :creator_data,
    :creator_pid,
    :name,
    :map_name,
    :ally_team_config,
    game_version: nil,
    engine_version: nil,
    boss_enabled?: false,
    game_options: %{},
    tags: %{}
  ]

  @type t() :: %__MODULE__{
          creator_data: LT.PlayerJoinData.t(),
          creator_pid: pid(),
          name: String.t(),
          map_name: String.t(),
          ally_team_config: [LT.AllyTeamConfig.t()],
          game_version: String.t() | nil,
          engine_version: String.t() | nil,
          boss_enabled?: boolean(),
          game_options: %{String.t() => String.t()},
          tags: %{String.t() => map()}
        }
end
