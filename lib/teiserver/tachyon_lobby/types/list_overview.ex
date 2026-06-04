defmodule Teiserver.TachyonLobby.Types.ListOverview do
  @moduledoc """
  Subset of a lobby overview used for listing.
  This data is sent to any client that subscribe to lobby updates so it's
  important to keep it as lean as possible.
  Any property there should be directly used by clients and otherwise culled
  """

  @enforce_keys [
    :name,
    :player_count,
    :max_player_count,
    :map_name,
    :engine_version,
    :game_version,
    :boss_enabled?
  ]
  defstruct [
    :name,
    :player_count,
    :max_player_count,
    :map_name,
    :engine_version,
    :game_version,
    :boss_enabled?,
    current_battle: nil,
    tags: %{}
  ]

  @type t() :: %__MODULE__{
          name: String.t(),
          player_count: non_neg_integer(),
          max_player_count: non_neg_integer(),
          map_name: String.t(),
          engine_version: String.t(),
          game_version: String.t(),
          boss_enabled?: boolean(),
          current_battle: %{started_at: DateTime.t()} | nil,
          tags: %{String.t() => map()}
        }
end
