defmodule Teiserver.TachyonLobby.Events.VoteEnded do
  @moduledoc """
  Marks the end of the current vote
  """

  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:finished_at, :vote, :outcome]
  defstruct [:finished_at, :vote, :outcome]

  @type t() :: %__MODULE__{
          finished_at: DateTime.t(),
          vote: LT.VoteState.t(),
          outcome: LT.VoteState.vote_outcome()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.VoteEnded do
  alias Teiserver.TachyonLobby.Event
  alias Teiserver.TachyonLobby.Events
  alias Teiserver.TachyonLobby.Events.VoteEnded
  alias Teiserver.TachyonLobby.Types, as: LT

  # don't bother cancelling the vote timeout timer. The event handler checks the vote id
  # and it allows us not to worry about storing the tref
  def apply_event(%VoteEnded{} = ev, %LT.Aggregate{} = agg) do
    vote_record = %LT.VoteRecord{
      vote: ev.vote,
      finished_at: ev.finished_at,
      outcome: ev.outcome
    }

    history = Map.put(agg.data.vote_history, agg.data.current_vote.id, vote_record)

    max_vote_history_size = 10

    history =
      if map_size(history) > max_vote_history_size do
        dates =
          Enum.map(history, fn {_id, record} -> record.finished_at end)
          |> Enum.sort()

        cutoff = Enum.at(dates, 4)

        Enum.filter(history, fn {_id, record} -> record.finished_at >= cutoff end)
        |> Enum.into(%{})
      else
        history
      end

    data = %{agg.data | current_vote: nil, vote_history: history}

    changes =
      agg.changes
      |> Map.put(:current_vote, nil)
      |> Map.put_new(:vote_history, %{})
      |> put_in([:vote_history, ev.vote.id], %{
        vote: ev.vote.action,
        finished_at: ev.finished_at,
        outcome: ev.outcome
      })

    side_effects = [{:vote_ended, ev.vote, ev.outcome} | agg.side_effects]
    agg = %{agg | data: data, changes: changes, side_effects: side_effects}

    apply_outcome(agg, ev.outcome, ev.vote.action)
  end

  defp apply_outcome(agg, outcome, _action) when outcome != :passed, do: agg

  defp apply_outcome(agg, :passed, {:change_map, new_map}),
    do: Event.apply_event(%Events.UpdateMapName{new_map: new_map}, agg)

  defp apply_outcome(agg, :passed, {:appoint_boss, boss_id}),
    do: Event.apply_event(%Events.UpdateBoss{action: :add, appointee_id: boss_id}, agg)

  defp apply_outcome(agg, :passed, {:kickban, target_id, ban_until}) do
    data = agg.data

    target_in_lobby? =
      is_map_key(data.players, target_id) or
        is_map_key(data.spectators, target_id)

    cond do
      target_in_lobby? ->
        Event.apply_event(%Events.Kickban{user_id: target_id, ban_until: ban_until}, agg)

      ban_until != nil ->
        effective_ban_until =
          if DateTime.compare(ban_until, DateTime.utc_now()) == :gt,
            do: ban_until,
            else: nil

        case effective_ban_until do
          nil ->
            agg

          dt ->
            ms = DateTime.diff(dt, DateTime.utc_now(), :millisecond)

            side_effects =
              if ms > 0,
                do: [{:send_after, ms, {:ban_expired, target_id}} | agg.side_effects],
                else: agg.side_effects

            new_data = put_in(data.banned_users[target_id], dt)
            %{agg | data: new_data, side_effects: side_effects}
        end

      true ->
        agg
    end
  end

  # just let the thing crash if a new vote action shows up. It'll be easy
  # to spot and fix/add support. :start isn't yet supported
end
