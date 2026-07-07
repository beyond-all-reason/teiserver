defmodule Teiserver.TachyonLobby.Types.Data do
  @moduledoc """
  Internal data for a lobby. Everything that's required for a lobby to run
  """

  alias Teiserver.Account.User
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [
    :id,
    :monitors,
    :name,
    :map_name,
    :game_version,
    :engine_version,
    :boss_enabled?,
    :ally_team_config
  ]
  defstruct [
    :id,
    :monitors,
    :name,
    :map_name,
    :game_version,
    :engine_version,
    :boss_enabled?,
    :ally_team_config,
    counter: 0,
    bosses: MapSet.new(),
    game_options: %{},
    tags: %{},
    players: %{},
    spectators: %{},
    bots: %{},
    bot_idx_counter: 0,
    current_battle: nil,
    ids_to_rejoin: MapSet.new(),
    vote_idx: 1,
    current_vote: nil,
    vote_history: %{},
    banned_users: %{}
  ]

  @type t() :: %__MODULE__{
          id: LT.Types.id(),
          monitors: MC.t(),
          name: String.t(),
          game_version: String.t(),
          engine_version: String.t(),
          boss_enabled?: boolean(),
          bosses: MapSet.t(User.id()),
          ally_team_config: [LT.AllyTeamConfig.t()],
          counter: integer(),
          game_options: %{String.t() => String.t()},
          tags: %{String.t() => map()},
          players: %{LT.Types.player_id() => LT.PlayerDetails.t()},
          spectators: %{User.id() => LT.SpectatorDetails.t()},
          bots: %{LT.Bot.id() => LT.Bot.t()},
          bot_idx_counter: integer(),
          current_battle: LT.CurrentBattleDetails.t() | nil,
          ids_to_rejoin: MapSet.t(),
          vote_idx: integer(),
          current_vote: LT.VoteState.t() | nil,
          vote_history: %{String.t() => LT.VoteRecord.t()},
          banned_users: %{User.id() => DateTime.t()}
        }
end
