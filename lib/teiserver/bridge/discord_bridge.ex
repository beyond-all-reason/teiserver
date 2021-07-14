defmodule Teiserver.Bridge.DiscordBridge do
  # use Alchemy.Cogs
  use Alchemy.Events
  alias Teiserver.{Room}
  alias Teiserver.Bridge.BridgeServer
  require Logger

  Events.on_message(:inspect)
  def inspect(%Alchemy.Message{author: %{username: "Teiserver Bridge"}}) do
    # This is us, don't do anything
    :ok
  end

  def inspect(%Alchemy.Message{author: author, content: content, channel_id: channel_id}) do
    room = bridge_channel_to_room(channel_id)

    case room do
      nil ->
        Logger.debug("No room to send to")
        :ok

      _ ->
        Logger.debug("Sending to room")
        from_id = BridgeServer.get_bridge_userid()
        Room.send_message(from_id, room, "#{author.username}: #{content}")
    end
  end

  def inspect(event) do
    Logger.debug("Unhandled DiscordBridge event: #{Kernel.inspect event}")
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
