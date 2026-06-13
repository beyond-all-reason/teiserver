defmodule Teiserver.TachyonLobby.Events.CastVote do
  @moduledoc """
  To change the tags for a lobby
  """

  alias Teiserver.Account.User
  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:user_id, :vote, :ballot]
  defstruct [:user_id, :vote, :ballot]

  @type t() :: %__MODULE__{
          user_id: User.id(),
          vote: LT.VoteState.t(),
          ballot: LT.VoteState.vote_ballot()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.CastVote do
  alias Teiserver.TachyonLobby.Event
  alias Teiserver.TachyonLobby.Events
  alias Teiserver.TachyonLobby.Events.CastVote
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%CastVote{} = ev, %LT.Aggregate{} = agg)
      when agg.data.current_vote == nil or
             agg.data.current_vote.id != ev.vote.id or
             not is_map_key(agg.data.current_vote.voters, ev.user_id) do
    agg
  end

  def apply_event(%CastVote{} = ev, %LT.Aggregate{} = agg) do
    data =
      put_in(agg.data, [Access.key!(:current_vote), Access.key!(:voters), ev.user_id], ev.ballot)

    agg = %{agg | data: data}

    case vote_result(agg.data.current_vote) do
      :undecided ->
        changes =
          agg.changes
          |> Map.put_new(:current_vote, %{})
          |> Map.update!(:current_vote, &Map.put_new(&1, :voters, %{}))
          |> put_in([:current_vote, :voters, ev.user_id], ev.ballot)

        %{agg | changes: changes}

      {:ended, result} ->
        new_aggregate =
          Event.apply_event(
            %Events.VoteEnded{
              vote: data.current_vote,
              finished_at: DateTime.utc_now(),
              outcome: result
            },
            agg
          )

        case {result, ev.vote.action} do
          {:failed, _action} ->
            new_aggregate

          {:passed, {:change_map, new_map}} ->
            Event.apply_event(%Events.UpdateMapName{new_map: new_map}, new_aggregate)

          {:passed, {:appoint_boss, boss_id}} ->
            Event.apply_event(
              %Events.UpdateBoss{action: :add, appointee_id: boss_id},
              new_aggregate
            )

          {:passed, {:kickban, target_id, ban_until}} ->
            data = new_aggregate.data

            target_in_lobby? =
              is_map_key(data.players, target_id) or
                is_map_key(data.spectators, target_id)

            cond do
              target_in_lobby? ->
                Event.apply_event(
                  %Events.Kickban{user_id: target_id, ban_until: ban_until},
                  new_aggregate
                )

              ban_until != nil ->
                effective_ban_until =
                  if DateTime.compare(ban_until, DateTime.utc_now()) == :gt,
                    do: ban_until,
                    else: nil

                case effective_ban_until do
                  nil ->
                    new_aggregate

                  dt ->
                    ms = DateTime.diff(dt, DateTime.utc_now(), :millisecond)

                    side_effects =
                      if ms > 0,
                        do: [
                          {:send_after, ms, {:ban_expired, target_id}}
                          | new_aggregate.side_effects
                        ],
                        else: new_aggregate.side_effects

                    new_data = put_in(data.banned_users[target_id], dt)
                    %{new_aggregate | data: new_data, side_effects: side_effects}
                end

              true ->
                new_aggregate
            end

            # just let the thing crash if a new vote action shows up. It'll be easy
            # to spot and fix/add support. :start isn't yet supported
        end
    end
  end

  @spec vote_result(LT.VoteState.t()) :: :undecided | {:ended, :passed | :failed}
  defp vote_result(%LT.VoteState{} = vote) do
    votes = for {_user_id, v} <- vote.voters, do: v

    cond do
      Enum.count(votes, &(&1 != :pending)) < vote.quorum -> :undecided
      Enum.count(votes, &(&1 == :yes)) >= vote.majority -> {:ended, :passed}
      true -> {:ended, :failed}
    end
  end
end
