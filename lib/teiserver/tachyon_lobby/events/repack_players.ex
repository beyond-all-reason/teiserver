defmodule Teiserver.TachyonLobby.Events.RepackPlayers do
  @moduledoc """
  Reshuffle every player/bot team so that each stay in the same allyteam, but
  their team is now consecutive (without gap) and starts at 0.
  So that for example, [{0, 0, 0}, {0, 2, 0}] represent an ally team with 2 players
  but their team's index is not consecutive. After processing this event, it
  should be [{0, 0, 0}, {0, 1, 0}]
  """

  defstruct []
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.RepackPlayers do
  alias Teiserver.TachyonLobby.Events.MovePlayer
  alias Teiserver.TachyonLobby.Events.RepackPlayers
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%RepackPlayers{}, %LT.Aggregate{} = agg) do
    data = agg.data

    move_events =
      for {%LT.AllyTeamConfig{} = _at, at_idx} <- Enum.with_index(data.ally_team_config) do
        Enum.filter(data.players, fn {_id, %{team: {p_at, _team, _player}}} -> at_idx == p_at end)
        |> Enum.map(fn {_id, p} -> p end)
        |> Enum.sort_by(& &1.team)
        |> Enum.with_index()
        |> Enum.map(fn {p, idx} -> {p.id, put_elem(p.team, 1, idx)} end)
      end
      |> List.flatten()
      |> Enum.map(fn {p_id, team} ->
        if data.players[p_id].team != team do
          %MovePlayer{player_id: p_id, team: team}
        end
      end)
      |> Enum.reject(&is_nil/1)

    Enum.reduce(move_events, agg, &Teiserver.TachyonLobby.Event.apply_event/2)
  end
end
