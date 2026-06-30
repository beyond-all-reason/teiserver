defmodule Teiserver.TachyonLobby.Events.MovePlayerToSpec do
  @moduledoc """
  When a player becomes a spectator. This cannot be applied to a bot
  """
  alias Teiserver.Account.User

  @enforce_keys [:user_id, :spec_data]
  defstruct [:user_id, :spec_data]

  @type t() :: %__MODULE__{
          user_id: User.id(),
          spec_data: map()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.MovePlayerToSpec do
  alias Teiserver.TachyonLobby.Events
  alias Teiserver.TachyonLobby.Events.MovePlayerToSpec
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%MovePlayerToSpec{} = ev, %LT.Aggregate{} = agg) do
    %LT.Player{} = player = agg.data.players[ev.user_id]

    spec = %LT.Spectator{
      id: player.id,
      name: player.name,
      password: player.password,
      pid: player.pid,
      join_queue_position: ev.spec_data.join_queue_position
    }

    data =
      agg.data
      |> update_in([Access.key!(:players)], &Map.delete(&1, ev.user_id))
      |> put_in([Access.key!(:spectators), ev.user_id], spec)

    changes =
      agg.changes
      |> Map.put_new(:players, %{})
      |> put_in([:players, ev.user_id], nil)
      |> Map.put_new(:spectators, %{})
      |> put_in([:spectators, ev.user_id], ev.spec_data)

    overview_changes = Map.put(agg.overview_changes, :player_count, map_size(data.players))

    new_aggregate = %{agg | data: data, changes: changes, overview_changes: overview_changes}

    Enum.reduce(
      [%Events.RepackPlayers{}, %Events.FillFromJoinQueue{}],
      new_aggregate,
      &Teiserver.TachyonLobby.Event.apply_event/2
    )
  end
end
