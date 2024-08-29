defmodule Teiserver.Coordinator.SpadsParser do
  @moduledoc false
  alias Teiserver.{CacheUser, Account, Telemetry, Battle}

  @spec handle_in(String.t(), map()) :: {:host_update, map()} | nil
  def handle_in(msg, state) do
    cond do
      # Team Size
      match = Regex.run(~r/teamSize=(\d)+/, msg) ->
        [_, size] = match
        {:host_update, %{host_teamsize: String.to_integer(size)}}

      # Team count
      match = Regex.run(~r/nbTeams=(\d)+/, msg) ->
        [_, count] = match
        {:host_update, %{host_teamcount: String.to_integer(count)}}

      # Kick or ban a player
      match = Regex.run(~r/Battle ban added for user "(\S+)" \(duration: .*? by (\S+)\)/, msg) ->
        [_, _kicked_name, kicker_name] = match
        kicker_id = Account.get_userid_from_name(kicker_name)
        match_id = Battle.get_lobby_match_id(state.lobby_id)

        if kicker_id && match_id do
          Telemetry.log_simple_lobby_event(kicker_id, match_id, "Kicked user from lobby")
        end

        nil

      # Add a boss
      match = Regex.run(~r/Boss mode enabled for (\S+)/, msg) ->
        [_, player_name] = match
        player_id = CacheUser.get_userid(player_name)

        if player_id do
          new_bosses = [player_id | state.host_bosses]
          {:host_update, %{host_bosses: new_bosses}}
        else
          nil
        end

      # Remove all bosses
      _match = Regex.run(~r/Boss mode disabled by \S+/, msg) ->
        {:host_update, %{host_bosses: []}}

      # Not handling it, return nil
      true ->
        nil
    end
  end
end
