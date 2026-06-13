defmodule Teiserver.TachyonLobby.Events.RemoveSpecFromLobby do
  @moduledoc """
  Removing a spectator from the lobby
  """
  alias Teiserver.Account.User

  @enforce_keys [:user_id]
  defstruct [:user_id]

  @type t() :: %__MODULE__{
          user_id: User.id()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.RemoveSpecFromLobby do
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.TachyonLobby.Events
  alias Teiserver.TachyonLobby.Events.RemoveSpecFromLobby
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%RemoveSpecFromLobby{} = ev, %LT.Aggregate{} = agg) do
    # if the user leaving is associated with any bot, we need to remove all of
    # them as well.
    bot_ids_to_remove =
      Enum.filter(agg.data.players, fn {_bot_id, b} ->
        Map.get(b, :host_user_id) == ev.user_id
      end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.into(MapSet.new())

    data =
      agg.data
      |> update_in([Access.key!(:players)], fn players ->
        Enum.reject(players, fn {p_id, _data} -> MapSet.member?(bot_ids_to_remove, p_id) end)
        |> Enum.into(%{})
      end)
      |> update_in([Access.key!(:spectators)], &Map.delete(&1, ev.user_id))
      |> update_in([Access.key!(:monitors)], &MC.demonitor_by_val(&1, {:user, ev.user_id}))

    bot_changes = Enum.map(bot_ids_to_remove, fn id -> {id, nil} end) |> Enum.into(%{})

    changes =
      agg.changes
      |> Map.put_new(:players, %{})
      |> Map.update!(:players, &Map.merge(&1, bot_changes))
      |> Map.put_new(:spectators, %{})
      |> put_in([:spectators, ev.user_id], nil)

    overview_changes = Map.put(agg.overview_changes, :player_count, map_size(data.players))

    # TODO This should handle voting and boss updates once these are converted to structs
    # aggregate = process_event({:cast_vote, p_id, :abstain}, aggregate)
    # process_event({:update_boss, :remove, p_id}, aggregate)
    new_aggregate = %{agg | data: data, changes: changes, overview_changes: overview_changes}

    Enum.reduce(
      [%Events.RepackPlayers{}, %Events.FillFromJoinQueue{}],
      new_aggregate,
      &Teiserver.TachyonLobby.Event.apply_event/2
    )
  end
end
