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
    %{agg | data: data, changes: changes, side_effects: side_effects}
  end
end
