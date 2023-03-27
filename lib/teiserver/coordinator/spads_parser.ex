defmodule Teiserver.Coordinator.SpadsParser do
  alias Teiserver.User

  @spec handle_in(String.t(), map()) :: {:host_update, Map.t()} | nil
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

      # Add a boss
      match = Regex.run(~r/Boss mode enabled for (\S+)/, msg) ->
        [_, player_name] = match
        player_id = User.get_userid(player_name)

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
