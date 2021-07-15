defmodule Teiserver.Bridge.DiscordBridge do
  # use Alchemy.Cogs
  use Alchemy.Events
  alias Teiserver.{Room}
  alias Teiserver.Bridge.BridgeServer
  require Logger

  Events.on_message(:inspect)
  def inspect(%Alchemy.Message{author: author, channel_id: channel_id} = message) do
    room = bridge_channel_to_room(channel_id)

    cond do
      author.username == Application.get_env(:central, DiscordBridge)[:bot_name] ->
        nil

      room == nil ->
        nil

      true ->
        do_reply(message)
    end
  end

  def inspect(event) do
    Logger.debug("Unhandled DiscordBridge event: #{Kernel.inspect event}")
  end

  defp do_reply(%Alchemy.Message{author: author, content: content, channel_id: channel_id, mentions: mentions}) do
    # Mentions come through encoded in a way we don't want to preserve, this substitutes them
    content = mentions
    |> Enum.reduce(content, fn (m, acc) ->
      String.replace(acc, "<@!#{m.id}>", m.username)
    end)

    from_id = BridgeServer.get_bridge_userid()
    room = bridge_channel_to_room(channel_id)
    Room.send_message(from_id, room, "#{author.username}: #{content}")
  end

  defp bridge_channel_to_room(channel_id) do
    result = Application.get_env(:central, DiscordBridge)[:bridges]
    |> Enum.filter(fn {chan, _room} -> chan == channel_id end)

    case result do
      [{_, room}] -> room
      _ -> nil
    end
  end
end
