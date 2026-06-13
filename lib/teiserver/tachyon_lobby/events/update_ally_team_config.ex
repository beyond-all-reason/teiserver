defmodule Teiserver.TachyonLobby.Events.UpdateAllyTeamConfig do
  @moduledoc """
  Modify ally team configuration. This may end up in a lot of player movements.
  Players should stay as players whenever possible, but may have to be moved
  from one team to another. If the new ally team configuration is too small then
  some players will be put at the beginning of the join queue
  """
  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:old_config, :new_config]
  defstruct [:old_config, :new_config]

  @type t() :: %__MODULE__{
          old_config: LT.AllyTeamConfig.t(),
          new_config: LT.AllyTeamConfig.t()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.UpdateAllyTeamConfig do
  alias Teiserver.Helpers.Collections
  alias Teiserver.TachyonLobby.Events
  alias Teiserver.TachyonLobby.Events.UpdateAllyTeamConfig
  alias Teiserver.TachyonLobby.Lobby
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%UpdateAllyTeamConfig{} = ev, %LT.Aggregate{} = agg) do
    spec_ids =
      Enum.map(agg.data.players, fn {p_id, %{team: {x, y, z}}} ->
        with at_config = %LT.AllyTeamConfig{} when not is_nil(at_config) <-
               Enum.at(ev.new_config, x),
             team_config when not is_nil(team_config) <- Enum.at(at_config.teams, y) do
          if y < at_config.max_teams && z < team_config.max_players,
            do: nil,
            else: p_id
        else
          nil -> p_id
        end
      end)
      |> Enum.reject(&is_nil/1)

    {bot_ids, player_ids} = Enum.split_with(spec_ids, &Lobby.bot_id?/1)

    position_offset =
      case Lobby.get_first_player_in_join_queue(agg.data.spectators) do
        nil -> 0
        spec_id -> agg.data.spectators[spec_id].join_queue_position - Enum.count(player_ids) - 1
      end

    spec_events =
      Enum.with_index(player_ids, position_offset)
      |> Enum.map(fn {p_id, pos} ->
        %Events.MovePlayerToSpec{user_id: p_id, spec_data: %{join_queue_position: pos}}
      end)

    bot_events = Enum.map(bot_ids, fn b_id -> %Events.RemovePlayerFromLobby{player_id: b_id} end)

    events = spec_events ++ bot_events ++ [%Events.RepackPlayers{}, %Events.FillFromJoinQueue{}]

    new_aggregate =
      Enum.reduce(
        events,
        %{agg | data: Map.replace!(agg.data, :ally_team_config, ev.new_config)},
        &Teiserver.TachyonLobby.Event.apply_event/2
      )

    # We put players in join queue, and then fill the teams with
    # the join queue, which means we can have events like
    # MovePlayerToSpec and later MoveSpecToPlayer
    # which would generate an update with %{spectators: %{x => nil}}
    # So we need to detect these and remove such updates
    changes =
      case Map.get(new_aggregate.changes, :spectators) do
        nil ->
          new_aggregate.changes

        spec_changes ->
          spec_changes =
            Enum.filter(spec_changes, fn {s_id, changes} ->
              changes != nil || is_map_key(agg.data.spectators, s_id)
            end)
            |> Enum.into(%{})

          if spec_changes == %{},
            do: Map.delete(new_aggregate.changes, :spectators),
            else: Map.put(new_aggregate.changes, :spectators, spec_changes)
      end

    at_changes =
      Collections.zip_with_padding(ev.old_config, ev.new_config, nil)
      |> Enum.map(fn
        {_old_at, nil} ->
          nil

        {nil, new_at} ->
          new_at

        {%LT.AllyTeamConfig{} = old_at, %LT.AllyTeamConfig{} = new_at} ->
          # we are broadcasting patch updates, so structs are meaningless
          # in this context
          new_at = Map.from_struct(new_at)

          Map.update!(new_at, :teams, fn new_teams ->
            Collections.zip_with_padding(old_at.teams, new_teams, nil)
            |> Enum.map(fn {_old_team, new_team} -> new_team end)
          end)
      end)

    changes = Map.put(changes, :ally_team_config, at_changes)

    new_max_player_count =
      Enum.sum(
        for at <- ev.new_config, team <- at.teams do
          team.max_players
        end
      )

    overview_changes =
      Map.put(new_aggregate.overview_changes, :max_player_count, new_max_player_count)

    %{new_aggregate | changes: changes, overview_changes: overview_changes}
  end
end
