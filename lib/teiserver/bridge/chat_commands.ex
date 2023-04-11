defmodule Teiserver.Bridge.ChatCommands do
  @moduledoc false
  alias Teiserver.{Account, User}
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Bridge.UnitNames
  alias Nostrum.Api
  require Logger

  @always_allow ~w(whatwas unit define whatis)

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
    gdt_forum =
      Application.get_env(:central, DiscordBridge)[:bridges]
      |> Enum.filter(fn {_, name} -> name == "gdt-discussion" end)

    case gdt_forum do
      [{forum_id, _}] ->
        # Post message to channel
        Api.create_message(
          channel_id,
          "Thank you for your suggestion, the game design team will be discussing it. Once they have finished discussing it they will vote on it and post an update to this thread."
        )

        # Delete the message that was posted
        Api.delete_message(channel_id, message_id)

        # channel_id = 1071140326644920353
        {:ok, channel} = Api.get_channel(channel_id)

        # Create new thread in gdt-discussion
        {:ok, thread} =
          Api.start_thread(forum_id, %{
            name: "Discussion for #{channel.name}",
            message: %{
              content: "Thread to discuss #{channel.name} - <##{channel_id}>"
            },
            type: 11
          })

        {:ok, message} =
          Api.create_message(thread.id, %{
            content: "Thread to discuss #{channel.name} - <##{channel_id}>"
          })

        # Pin message
        Api.add_pinned_channel_message(thread.id, message.id)

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
          Nostrum.Api.add_thread_member(thread.id, user_discord_id)
        end)

      _ ->
        :ok
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

  def handle_command({_user, _discord_id, _message_id}, "whatis", remaining, channel) do
    name =
      remaining
      |> String.trim()
      |> String.downcase()

    description =
      case name do
        "tachyon" ->
          """
          Tachyon is a protocol used to define messaging between the server and clients. It is built in JSON though we use Typescript to build our JSON schema.
          Tachyon is designed to allow us to scale beyond the limitations of our current legacy protocol (spring) as it has what is called an "O(n^2)" scaling problem where the number of messages (and thus work to do) grows multiple times faster than the number of users and thus putting a hard cap on how many people can play the game at once.
          Tachyon is considered a hard "must have" for our Steam release.
          You can get more involved with the development of it by checking out <#943582636679520256> (note: you may need to grab a dev role from the assign roles channel).
          """

        "teiserver" ->
          """
          Teiserver is the middleware server through which all clients communicate. Some of the items it handles are: Accounts/Authentication, Chat, Lobby coordination, Ratings and Moderation. If the server is working you likely won't even know it's there, if it stops working then so does everything else.
          Teiserver is written in Elixir, has some documentation and is very open to new contributors.
          You can get more involved with the development of it by checking out <#564591092360675328> (note: you may need to grab a dev role from the assign roles channel).
          """

        "spads" ->
          """
          SPADS is the software running the lobby rooms (battles). It's written in Perl, is very extensively documented and mature software. We are not expecting to make any notable changes to it.
          You can ask questions about it in <#564591092360675328> (note: you may need to grab a dev role from the assign roles channel).
          """

        "love" ->
          "Baby don't hurt me"
      end

    if description do
      reply(channel, description)
    else
      :ignore
    end
  end

  def handle_command(_, _, _, _) do
    :ignore
  end

  @spec allow?(String.t(), map()) :: boolean
  defp allow?("discord", _), do: true
  defp allow?("gdt", user), do: User.has_any_role?(user, ["Admin", "Moderator", "GDT"])

  defp allow?(cmd, user) do
    if Enum.member?(@always_allow, cmd) do
      true
    else
      User.allow?(user, "Moderator")
    end
  end

  defp reply(channel, message) do
    Api.create_message(channel, message)
    :ignore
  end
end
