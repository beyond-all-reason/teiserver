defmodule Teiserver.Bridge.ChatCommands do
  @moduledoc false
  alias Teiserver.{Account, CacheUser, Communication, Config, Logging}
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Bridge.UnitNames
  alias Nostrum.Api
  require Logger

  @always_allow ~w(whatwas unit define text)

  @spec handle(Nostrum.Struct.Message.t()) :: any
  def handle(%Nostrum.Struct.Message{
        id: message_id,
        author: %{id: author_id},
        channel_id: channel_id,
        content: "$" <> content,
        attachments: []
      }) do
    [cmd | remaining] = String.split(content, " ")
    remaining = Enum.join(remaining, " ")
    user = Account.get_user_by_discord_id(author_id)

    if allow?(cmd, user) do
      handle_command({user, author_id, message_id}, cmd, remaining, channel_id)
    end
  end

  def handle(_) do
    :ok
  end

  @spec handle_command({T.user(), String.t()}, String.t(), String.t(), non_neg_integer()) :: any
  def handle_command({user, discord_id, _message_id}, "echo", remaining, channel_id) do
    reply(channel_id, "Echoing <@!#{discord_id}> (aka #{user.name}), #{remaining}")
  end

  def handle_command({_user, _discord_id, message_id}, "gdt", _remaining, channel_id) do
    gdt_discussion_channel_id =
      Config.get_site_config_cache("teiserver.Discord forum #gdt-discussion")

    if gdt_discussion_channel_id do
      # Post message to channel
      Api.Message.create(
        channel_id,
        "Thank you for your suggestion, the game design team will be discussing it. Once they have finished discussing it they will vote on it and post an update to this thread."
      )

      # Delete the message that was posted
      Api.Message.delete(channel_id, message_id)

      # channel_id = 1071140326644920353
      {:ok, channel} = Api.Channel.get(channel_id)

      # Create new thread in gdt-discussion
      {:ok, thread} =
        Api.Thread.create_in_forum(gdt_discussion_channel_id, %{
          name: "Discussion for #{channel.name}",
          message: %{
            content: "Thread to discuss #{channel.name} - <##{channel_id}>"
          },
          type: 11
        })

      {:ok, message} =
        Api.Message.create(thread.id, %{
          content: "Thread to discuss #{channel.name} - <##{channel_id}>"
        })

      # Pin message
      Api.Channel.pin_message(thread.id, message.id)

      # Add GDTs to thread
      Account.list_users(
        search: [
          gdt_member: "GDT"
        ],
        select: [:data]
      )
      |> Enum.map(fn %{data: data} -> data["discord_id"] end)
      |> Enum.reject(&(&1 == nil))
      |> Enum.each(fn user_discord_id ->
        Api.Thread.add_member(thread.id, user_discord_id)
      end)
    end

    :ignore
  end

  def handle_command({_user, _discord_id, _message_id}, "whatwas", remaining, channel) do
    name =
      remaining
      |> String.trim()
      |> String.downcase()

    case UnitNames.get_name(name) do
      nil ->
        reply(channel, "Unable to find a unit named or previously named '#{remaining}'")

      {:code, actual_name} ->
        reply(channel, "#{name} is the internal name for #{actual_name |> String.capitalize()}")

      {:reused, {{_new_code, new_name}, {_old_code, old_name}}} ->
        reply(
          channel,
          "#{name |> String.capitalize()} was renamed to #{new_name |> String.capitalize()} and #{old_name |> String.capitalize()} was renamed to #{name |> String.capitalize()}"
        )

      {:unchanged, _} ->
        reply(channel, "#{name |> String.capitalize()} did not have a name change")

      {:found_old, {_code, new_name}} ->
        reply(
          channel,
          "#{name |> String.capitalize()} is now called #{new_name |> String.capitalize()}"
        )

      {:found_new, {_code, old_name}} ->
        reply(
          channel,
          "#{name |> String.capitalize()} used to be called #{old_name |> String.capitalize()}"
        )
    end
  end

  def handle_command({_user, _discord_id, _message_id}, "unit", remaining, channel) do
    name =
      remaining
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
        reply(
          channel,
          "Can't find #{name |> String.capitalize()}, did you mean #{new_name |> String.capitalize()}?"
        )

      {:found_new, {code, _old_name}} ->
        reply(channel, "https://www.beyondallreason.info/unit/#{code}")
    end
  end

  def handle_command(cmd, "define", remaining, channel) do
    handle_command(cmd, "whatis", remaining, channel)
  end

  def handle_command({_user, discord_user_id, message_id}, "text", remaining, channel_id) do
    case Communication.lookup_text_callback_from_trigger(remaining) do
      nil ->
        :ignore

      text_callback ->
        if Communication.can_trigger_callback?(text_callback, channel_id) do
          Logging.add_anonymous_audit_log("Discord.text_callback", %{
            discord_user_id: discord_user_id,
            discord_channel_id: channel_id,
            command: text_callback.id,
            trigger: remaining
          })

          if text_callback.rules["delete_trigger"] == "true" do
            Api.Message.delete(channel_id, message_id)
          end

          Communication.set_last_triggered_time(text_callback, channel_id)

          reply(channel_id, text_callback.response)
        else
          :ok
        end
    end
  end

  def handle_command(_, _, _, _) do
    :ignore
  end

  @spec allow?(String.t(), map()) :: boolean
  defp allow?("discord", _), do: true
  defp allow?("gdt", user), do: CacheUser.has_any_role?(user, ["Admin", "Moderator", "GDT"])

  defp allow?(cmd, user) do
    if Enum.member?(@always_allow, cmd) do
      true
    else
      CacheUser.allow?(user, "Moderator")
    end
  end

  defp reply(channel, message) do
    Api.Message.create(channel, message)
    :ignore
  end
end
