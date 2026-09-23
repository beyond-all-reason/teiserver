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
  alias Teiserver.TachyonLobby.Lobby
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

    case Lobby.vote_result(agg.data.current_vote) do
      :undecided ->
        changes =
          agg.changes
          |> Map.put_new(:current_vote, %{})
          |> Map.update!(:current_vote, &Map.put_new(&1, :voters, %{}))
          |> put_in([:current_vote, :voters, ev.user_id], ev.ballot)

        %{agg | changes: changes}

      {:ended, result} ->
        Event.apply_event(
          %Events.VoteEnded{
            vote: data.current_vote,
            finished_at: DateTime.utc_now(),
            outcome: result
          },
          agg
        )
    end
  end
end
