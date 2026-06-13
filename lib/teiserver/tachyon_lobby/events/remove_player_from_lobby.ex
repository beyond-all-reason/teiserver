defmodule Teiserver.TachyonLobby.Events.RemovePlayerFromLobby do
  @moduledoc """
  Removing a player or a bot from the lobby
  """
  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:player_id]
  defstruct [:player_id]

  @type t() :: %__MODULE__{
          player_id: LT.Types.player_id()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.RemovePlayerFromLobby do
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.TachyonLobby.Events
  alias Teiserver.TachyonLobby.Events.RemovePlayerFromLobby
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%RemovePlayerFromLobby{} = ev, %LT.Aggregate{} = agg) do
    # if the user leaving is associated with any bot, we need to remove all of
    # them as well.
    ids_to_remove =
      Enum.filter(agg.data.players, fn {_bot_id, b} ->
        Map.get(b, :host_user_id) == ev.player_id
      end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.into(MapSet.new([ev.player_id]))

    data =
      agg.data
      |> update_in([Access.key!(:players)], fn players ->
        Enum.reject(players, fn {p_id, _data} -> MapSet.member?(ids_to_remove, p_id) end)
        |> Enum.into(%{})
      end)
      |> update_in([Access.key!(:monitors)], &MC.demonitor_by_val(&1, {:user, ev.player_id}))

    removed_changes = Enum.map(ids_to_remove, fn id -> {id, nil} end) |> Enum.into(%{})

    changes =
      agg.changes
      |> Map.put_new(:players, %{})
      |> update_in([:players], &Map.merge(&1, removed_changes))

    overview_changes = Map.put(agg.overview_changes, :player_count, map_size(data.players))

    # TODO This should handle voting and boss updates once these are converted to structs
    # aggregate = process_event({:cast_vote, p_id, :abstain}, aggregate)
    # process_event({:update_boss, :remove, p_id}, aggregate)
    # TODO: this should handle cancelling kickban vote as well
    new_aggregate = %{agg | data: data, changes: changes, overview_changes: overview_changes}

    Enum.reduce(
      [%Events.RepackPlayers{}, %Events.FillFromJoinQueue{}],
      new_aggregate,
      &Teiserver.TachyonLobby.Event.apply_event/2
    )
  end
end
