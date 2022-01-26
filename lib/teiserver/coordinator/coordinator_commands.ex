defmodule Teiserver.Coordinator.CoordinatorCommands do
  alias Teiserver.{User, Account, Client}
  alias Teiserver.Account.AccoladeLib

  @always_allow ~w(whoami discord)

  @spec allow_command?(Map.t(), Map.t()) :: boolean()
  defp allow_command?(%{senderid: senderid} = cmd, _state) do
    client = Client.get_client_by_id(senderid)

    cond do
      client == nil -> false
      Enum.member?(@always_allow, cmd.command) -> true
      client.moderator == true -> true
      true -> false
    end
  end

  @spec handle_command(map(), map()) :: map()
  def handle_command(cmd, state) do
    if allow_command?(cmd, state) do
      do_handle(cmd, state)
    else
      state
    end
  end

  # Public commands
  @spec do_handle(map(), map()) :: map()
  defp do_handle(%{command: "whoami", senderid: senderid} = _cmd, state) do
    sender = User.get_user_by_id(senderid)
    stats = Account.get_user_stat_data(senderid)

    player_hours = Map.get(stats, "player_minutes", 0)/60 |> round
    spectator_hours = Map.get(stats, "spectator_minutes", 0)/60 |> round
    rank_time = User.rank_time(senderid)

    accolades = AccoladeLib.get_player_accolades(senderid)
    accolades_string = case Map.keys(accolades) do
      [] ->
        "You currently have no accolades"

      _ ->
        badge_types = Account.list_badge_types(search: [id_list: Map.keys(accolades)])
        |> Map.new(fn bt -> {bt.id, bt} end)

        ["Your accolades are as follows:"] ++
          (accolades
          |> Enum.map(fn {bt_id, count} ->
            ">> #{count}x #{badge_types[bt_id].name}"
          end))
    end

    msg = [
      "You are #{sender.name}",
      "Rank: #{sender.rank+1} with #{player_hours} player hours and #{spectator_hours} spectator hours for a rank hour count of #{rank_time}",
      accolades_string
    ]
    |> List.flatten

    User.send_direct_message(state.userid, senderid, msg)
    state
  end

  defp do_handle(%{command: "discord", senderid: senderid} = _cmd, state) do
    sender = User.get_user_by_id(senderid)

    if sender.discord_id != nil do
      User.send_direct_message(state.userid, senderid, "You already have a discord account linked.")
    else
      code = :rand.uniform(899999) + 100000 |> to_string
      ConCache.put(:discord_bridge_account_codes, senderid, code)

      User.send_direct_message(state.userid, senderid, [
        "To link your discord account, message the the discord bot (Teiserver Bridge) with the message",
        "$discord #{senderid}-#{code}",
        "This code will expire after 5 minutes",
      ])
    end

    state
  end

  # Moderator commands
  defp do_handle(%{command: "whois", senderid: senderid, remaining: remaining} = _cmd, state) do
    case User.get_user_by_name(remaining) do
      nil ->
        User.send_direct_message(state.userid, senderid, "Unable to find a user with that name")
      user ->
        stats = Account.get_user_stat_data(user.id)

        player_hours = Map.get(stats, "player_minutes", 0)/60 |> round
        spectator_hours = Map.get(stats, "spectator_minutes", 0)/60 |> round
        rank_time = User.rank_time(user.id)

        accolades = AccoladeLib.get_player_accolades(user.id)
        accolades_string = case Map.keys(accolades) do
          [] ->
            "They currently have no accolades"

          _ ->
            badge_types = Account.list_badge_types(search: [id_list: Map.keys(accolades)])
            |> Map.new(fn bt -> {bt.id, bt} end)

            ["Accolades as follows:"] ++
              (accolades
              |> Enum.map(fn {bt_id, count} ->
                ">> #{count}x #{badge_types[bt_id].name}"
              end))
        end

        msg = [
          "Found #{user.name}",
          "Rank: #{user.rank+1} with #{player_hours} player hours and #{spectator_hours} spectator hours for a rank hour count of #{rank_time}",
          accolades_string
        ]
        |> List.flatten

        User.send_direct_message(state.userid, senderid, msg)
    end
    state
  end

  defp do_handle(%{command: command, senderid: senderid} = _cmd, state) do
    User.send_direct_message(state.userid, senderid, "I don't have a handler for the command '#{command}'")
    state
  end
end
