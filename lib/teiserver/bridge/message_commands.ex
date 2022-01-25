defmodule Teiserver.Bridge.MessageCommands do
  @moduledoc false
  alias Teiserver.User
  alias Central.Helpers.NumberHelper

  def handle(%Alchemy.Message{author: %{id: author}, channel_id: channel, content: "$" <> content, attachments: []} = _message) do
    [cmd | remaining] = String.split(content, " ")
    remaining = Enum.join(remaining, " ")
    user = User.get_user_by_discord_id(author)

    handle_command({user, author}, cmd, remaining, channel)
  end

  def handle(_) do
    :ok
  end

  def handle_command({nil, discord_id}, "discord", remaining, channel) do
    case String.split(remaining, "-") do
      [userid_str, given_code] ->
        userid = NumberHelper.int_parse(userid_str)
        correct_code = ConCache.get(:discord_bridge_account_codes, userid)

        if given_code == correct_code do
          ConCache.delete(:discord_bridge_account_codes, userid)
          user = User.get_user_by_id(userid)
          User.update_user(%{user | discord_id: discord_id}, persist: true)
          ConCache.put(:users_lookup_id_with_discord_id, discord_id, user.id)

          reply(channel, "Congratulations, your accounts are now linked.")
        else
          reply(channel, "This code is incorrect.")
        end

      _ ->
        reply(channel, "Invalid code")
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

  def handle_command({_sender, _}, "discord", _remaining, channel) do
    reply(channel, "Your account is linked but at the moment there's nothing else I can do.")
  end

  defp reply(channel, message) do
    Alchemy.Client.send_message(
      channel,
      message,
      []# Options
    )
  end
end
