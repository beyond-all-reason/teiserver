defmodule Teiserver.Bridge.ChatCommands do
  @moduledoc false
  alias Teiserver.User
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Bridge.UnitNames

  @always_allow ~w(whatwas)

  def handle(%Alchemy.Message{author: %{id: author}, channel_id: channel, content: "$" <> content, attachments: []} = _message) do
    [cmd | remaining] = String.split(content, " ")
    remaining = Enum.join(remaining, " ")
    user = User.get_user_by_discord_id(author)

    if allow?(cmd, user) do
      handle_message({user, author}, cmd, remaining, channel)
    end
  end

  @spec handle_message({T.user(), String.t()}, String.t(), String.t(), String.t()) :: any
  def handle_message({user, discord_id}, "echo", remaining, channel) do
    reply(channel, "Echoing <@!#{discord_id}> (aka #{user.name}), #{remaining}")
  end

  def handle_message({_user, _discord_id}, "whatwas", remaining, channel) do
    name = remaining
      |> String.trim()
      |> String.downcase()

    case UnitNames.get_name(name) do
      nil ->
        reply(channel, "Unable to find a unit named or previously named '#{remaining}'")
      {:old_to_new, new_name, code} ->
        old_name = String.capitalize(name)
        new_name = String.capitalize(new_name)

        reply(channel, "#{old_name} is now called #{new_name} - https://www.beyondallreason.info/unit/#{code}")
      {:new_to_old, old_name, code} ->
        new_name = String.capitalize(name)
        old_name = String.capitalize(old_name)

        reply(channel, "#{new_name} used to be called #{old_name} - https://www.beyondallreason.info/unit/#{code}")
    end


  end

  def handle_message(_, _, _, _) do
    nil
  end

  @spec allow?(map(), map()) :: boolean
  defp allow?(cmd, user) do
    if Enum.member?(@always_allow, cmd) do
      true
    else
      User.allow?(user, "Moderator")
    end
  end

  defp reply(channel, message) do
    Alchemy.Client.send_message(
      channel,
      message,
      []# Options
    )
  end
end
