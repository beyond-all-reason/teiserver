defmodule Teiserver.TachyonLobby.Events.MoveSpecToPlayer do
  @moduledoc """
  Move a spectator into an ally team
  """

  alias Teiserver.Account.User

  @enforce_keys [:user_id, :player_data]
  defstruct [:user_id, :player_data]

  @type t() :: %__MODULE__{
          user_id: User.id(),
          player_data: map()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.MoveSpecToPlayer do
  alias Teiserver.TachyonLobby.Events.MoveSpecToPlayer
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%MoveSpecToPlayer{} = ev, %LT.Aggregate{} = agg) do
    spec_data = agg.data.spectators[ev.user_id]

    player = %LT.Player{
      id: spec_data.id,
      name: spec_data.name,
      password: spec_data.password,
      pid: spec_data.pid,
      team: ev.player_data.team,
      ready?: false,
      asset_status: :complete
    }

    data =
      agg.data
      |> update_in([Access.key!(:spectators)], &Map.delete(&1, ev.user_id))
      |> put_in([Access.key!(:players), ev.user_id], player)

    player_data = Map.merge(%{ready?: false, asset_status: :complete}, ev.player_data)

    changes =
      agg.changes
      |> Map.put_new(:players, %{})
      |> put_in([:players, ev.user_id], player_data)
      |> Map.put_new(:spectators, %{})
      |> put_in([:spectators, ev.user_id], nil)

    overview_changes = Map.put(agg.overview_changes, :player_count, map_size(data.players))

    %{agg | data: data, changes: changes, overview_changes: overview_changes}
  end
end
