defmodule Teiserver.Bridge.ChatCommands do
  @moduledoc false
  # alias Teiserver.User
  alias Teiserver.Data.Types, as: T

  # @always_allow ~w()

  # def handle(%Alchemy.Message{author: %{id: author}, channel_id: channel, content: "$" <> content, attachments: []} = _message) do
  #   [cmd | remaining] = String.split(content, " ")
  #   remaining = Enum.join(remaining, " ")
  #   user = User.get_user_by_discord_id(author)

  #   if allow?(cmd, user) do
  #     handle_message({user, author}, cmd, remaining, channel)
  #   end
  # end

  def handle(_) do
    :ok
  end

  @spec handle_message({T.user(), String.t()}, String.t(), String.t(), String.t()) :: any
  def handle_message({user, discord_id}, "echo", remaining, channel) do
    reply(channel, "Echoing <@!#{discord_id}> (aka #{user.name}), #{remaining}")
  end

  def handle_message(_, _, _, _) do
    nil
  end

  # @spec allow?(map(), map()) :: boolean
  # defp allow?(cmd, user) do
  #   if Enum.member?(@always_allow, cmd) do
  #     true
  #   else
  #     User.allow?(user, "Moderator")
  #   end
  # end

  defp reply(channel, message) do
    Alchemy.Client.send_message(
      channel,
      message,
      []# Options
    )
  end
end
