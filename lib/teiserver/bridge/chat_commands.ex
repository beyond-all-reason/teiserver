defmodule Teiserver.Bridge.ChatCommands do
  @moduledoc false
  alias Teiserver.User
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Bridge.UnitNames

  @always_allow ~w(whatwas unit)

  @spec handle(Alchemy.Message.t()) :: any
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

      {:code, actual_name} ->
        reply(channel, "#{name} is the internal name for #{actual_name |> String.capitalize()}")

      {:reused, {{_old_code, old_name}, {_new_code, new_name}}} ->
        reply(channel, "#{name |> String.capitalize()} was renamed to #{new_name |> String.capitalize()} and #{old_name |> String.capitalize()} was renamed to #{name |> String.capitalize()}")

      {:unchanged, _} ->
        reply(channel, "#{name |> String.capitalize()} did not have a name change")

      {:found_old, {_code, new_name}} ->
        reply(channel, "#{name |> String.capitalize()} is now called #{new_name |> String.capitalize()}")

      {:found_new, {_code, old_name}} ->
        reply(channel, "#{name |> String.capitalize()} used to be called #{old_name |> String.capitalize()}")
    end
  end

  def handle_message({_user, _discord_id}, "unit", remaining, channel) do
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
