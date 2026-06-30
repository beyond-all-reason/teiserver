defmodule Teiserver.TachyonLobby.Events.FillFromJoinQueue do
  @moduledoc """
  Add any player from the join queue to the list of active players whereverer
  there is space, attempting to fill the least full teams first
  """

  defstruct []
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.FillFromJoinQueue do
  alias Teiserver.Account.User
  alias Teiserver.TachyonLobby.Events
  alias Teiserver.TachyonLobby.Events.FillFromJoinQueue
  alias Teiserver.TachyonLobby.Lobby
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%FillFromJoinQueue{}, %LT.Aggregate{} = agg) do
    case add_player_from_join_queue(agg.data) do
      nil ->
        agg

      {id, player_data} ->
        ev = %Events.MoveSpecToPlayer{user_id: id, player_data: player_data}
        new_aggregate = Teiserver.TachyonLobby.Event.apply_event(ev, agg)
        apply_event(%FillFromJoinQueue{}, new_aggregate)
    end
  end

  # Add the first player from the join queue to the player list and returns the
  # updated state alongside the player id that was added
  @spec add_player_from_join_queue(LT.Data.t()) :: {User.id(), map()} | nil
  defp add_player_from_join_queue(%LT.Data{} = state) do
    case Lobby.get_first_player_in_join_queue(state.spectators) do
      nil ->
        nil

      id ->
        case Lobby.find_team(state.ally_team_config, state.players) do
          nil ->
            nil

          team ->
            {id, %{team: team, ready?: false, asset_status: :complete}}
        end
    end
  end
end
