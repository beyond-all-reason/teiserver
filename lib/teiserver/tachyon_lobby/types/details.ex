defmodule Teiserver.TachyonLobby.Types.Details do
  @moduledoc """
  Public, detailed data of a lobby. This is derived from the internal data
  and contains everything that's required for player/specs in the lobby.
  """

  alias Teiserver.Account.User
  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [
    :id,
    :name,
    :map_name,
    :game_version,
    :engine_version,
    :boss_enabled?,
    :ally_team_config
  ]
  defstruct [
    :id,
    :name,
    :map_name,
    :game_version,
    :engine_version,
    :boss_enabled?,
    :ally_team_config,
    bosses: MapSet.new(),
    game_options: %{},
    tags: %{},
    players: %{},
    spectators: %{},
    bots: %{},
    current_battle: nil,
    current_vote: nil,
    vote_history: %{}
  ]

  @type t() :: %__MODULE__{
          id: LT.Types.id(),
          name: String.t(),
          map_name: String.t(),
          game_version: String.t(),
          engine_version: String.t(),
          boss_enabled?: boolean(),
          bosses: MapSet.t(User.id()),
          ally_team_config: [LT.AllyTeamConfig.t()],
          game_options: %{String.t() => String.t()},
          tags: %{String.t() => map()},
          players: %{LT.Types.player_id() => LT.PlayerDetails.t()},
          spectators: %{User.id() => LT.SpectatorDetails.t()},
          bots: %{LT.Bot.id() => LT.Bot.t()},
          current_battle: LT.CurrentBattleDetails.t() | nil,
          current_vote: LT.VoteState.t() | nil,
          vote_history: %{String.t() => LT.VoteDetails.t()}
        }
end
