defmodule Teiserver.Player.Types.LobbyStartParams do
  @moduledoc """
  the same as TachyonLobby.Types.start_params,
  but without any creator data, these are filled by the session
  """
  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:name, :map_name, :ally_team_config]
  defstruct [
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
