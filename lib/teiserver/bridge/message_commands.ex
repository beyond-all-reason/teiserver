defmodule Teiserver.Bridge.MessageCommands do
  @moduledoc false
  alias Teiserver.{User, Account}
  alias Teiserver.Account.AccoladeLib
  alias Central.Helpers.NumberHelper
  alias alias Teiserver.Bridge.UnitNames
  require Logger

  @unauth ~w(discord)
  @always_allow ~w(whoami help whatwas unit)

  @spec handle(Alchemy.Message.t()) :: any
  def handle(%Alchemy.Message{author: %{id: author}, channel_id: channel, content: "$" <> content, attachments: []} = _message) do
    [cmd | remaining] = String.split(content, " ")
    remaining = Enum.join(remaining, " ")
    user = User.get_user_by_discord_id(author)

    if user do
      User.update_user(%{user |
        discord_dm_channel: channel
      }, persist: true)
    end

    allowed = allow?(cmd, user)
    Logger.info("MessageCommands.handle #{author}, #{content}, #{allowed}")

    if allow?(cmd, user) do
      handle_command({user, author}, cmd, remaining, channel)
    end
  end

  def handle(_) do
    :ok
  end

  @spec handle_command({T.user(), String.t()}, String.t(), String.t(), String.t()) :: any
  def handle_command({nil, _discord_id}, "discord", "", channel) do
    reply(channel, "To begin the process of linking your BAR account to your Discord account, please message the coordinator bot in BAR itself: `discord`")
  end

  def handle_command({nil, discord_id}, "discord", remaining, channel) do
    case String.split(remaining, "-") do
      [userid_str, given_code] ->
        userid = NumberHelper.int_parse(userid_str)
        correct_code = Central.cache_get(:discord_bridge_account_codes, userid)

        if given_code == correct_code do
          Central.cache_delete(:discord_bridge_account_codes, userid)
          user = User.get_user_by_id(userid)
          User.update_user(%{user |
            discord_id: discord_id,
            discord_dm_channel: channel
          }, persist: true)
          User.recache_user(user.id)

          reply(channel, "Congratulations, your accounts are now linked.")
        else
          reply(channel, "This code is incorrect.")
        end

      _ ->
        reply(channel, "Invalid code")
    end
  end

  def handle_command({_user, _discord_id}, "whatwas", remaining, channel) do
    name = remaining
      |> String.trim()
      |> String.downcase()

    case UnitNames.get_name(name) do
      nil ->
        reply(channel, "Unable to find a unit named or previously named '#{remaining}'")

      {:code, actual_name} ->
        reply(channel, "#{name} is the internal name for #{actual_name |> String.capitalize()}")

      {:reused, {{_new_code, new_name}, {_old_code, old_name}}} ->
        reply(channel, "#{name |> String.capitalize()} was renamed to #{new_name |> String.capitalize()} and #{old_name |> String.capitalize()} was renamed to #{name |> String.capitalize()}")

      {:unchanged, _} ->
        reply(channel, "#{name |> String.capitalize()} did not have a name change")

      {:found_old, {_code, new_name}} ->
        reply(channel, "#{name |> String.capitalize()} is now called #{new_name |> String.capitalize()}")

      {:found_new, {_code, old_name}} ->
        reply(channel, "#{name |> String.capitalize()} used to be called #{old_name |> String.capitalize()}")
    end
  end

  def handle_command({_user, _discord_id}, "unit", remaining, channel) do
    name = remaining
      |> String.trim()
      |> String.downcase()

    case UnitNames.get_name(name) do
      nil ->
        reply(channel, "Unable to find a unit named '#{remaining}'")

      {:code, _actual_name} ->
        reply(channel, "https://www.beyondallreason.info/unit/#{name}")

      {:reused, {_old, {new_code, _new_name}}} ->
        reply(channel, "https://www.beyondallreason.info/unit/#{new_code}")

      {:unchanged, {code, _name}} ->
        reply(channel, "https://www.beyondallreason.info/unit/#{code}")

      {:found_old, {_code, new_name}} ->
        reply(channel, "Can't find #{name |> String.capitalize()}, did you mean #{new_name |> String.capitalize()}?")

      {:found_new, {code ,_old_name}} ->
        reply(channel, "https://www.beyondallreason.info/unit/#{code}")
    end
  end

  def handle_command({nil, _}, cmd, _remaining, channel) do
    response = case cmd do
      "help" ->
        "Currently I don't know which player you are. To link your BAR account with your discord account message the coordinator bot in-game with the message `$discord` and it will send you a code to send to me. Once you send that code I'll know who you are and can respond accordingly."

      _ ->
        "Unfortunately I don't understand that command"
    end
    reply(channel, response)
  end

  def handle_command({user, _}, "whoami", _remaining, channel) do
    stats = Account.get_user_stat_data(user.id)

    player_hours = Map.get(stats, "player_minutes", 0)/60 |> round
    spectator_hours = Map.get(stats, "spectator_minutes", 0)/60 |> round
    rank_time = User.rank_time(user.id)

    host = Application.get_env(:central, CentralWeb.Endpoint)[:url][:host]
    profile_link = "https://#{host}/teiserver/profile/#{user.id}"

    accolades = AccoladeLib.get_player_accolades(user.id)
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
      "You are #{user.name}",
      "Profile link: #{profile_link}",
      "Rank: #{user.rank+1} with #{player_hours} player hours and #{spectator_hours} spectator hours for a rank hour count of #{rank_time}",
      accolades_string
    ]
    |> List.flatten

    reply(channel, msg)
  end

  def handle_command({_sender, _}, "help", _remaining, channel) do
    reply(channel, "Currently we don't have a list of commands, please feel free to suggest them to Teifion though!.")
  end

  def handle_command({_sender, _}, "discord", _remaining, channel) do
    reply(channel, "Your account is already linked.")
  end

  def handle_command({_sender, _}, _, _remaining, channel) do
    reply(channel, "Your account is linked but at the moment there's nothing else I can do.")
  end

  defp allow?(cmd, nil), do: Enum.member?(@unauth, cmd)
  defp allow?(cmd, user) do
    cond do
      Enum.member?(@unauth, cmd) ->
        true
      Enum.member?(@always_allow, cmd) ->
        true
      true ->
        User.allow?(user, "Moderator")
    end
  end

  defp reply(channel, message) when is_list(message), do: reply(channel, Enum.join(message, "\n"))
  defp reply(channel, message) do
    Alchemy.Client.send_message(
      channel,
      message,
      []# Options
    )
  end
end
