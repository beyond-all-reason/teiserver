defmodule Teiserver.Protocols.Tachyon.V1.SystemOut do
  @spec do_reply(atom(), any) :: Map.t()
  def do_reply(:pong, _data) do
    %{
      cmd: "s.system.pong",
      time: System.system_time(:second)
    }
  end

  def do_reply(:server_stats, data) do
    %{
      cmd: "s.system.server_stats",
      data: data
    }
  end

  def do_reply(:watch, {:ok, channel}) do
    %{
      cmd: "s.system.watch",
      result: "success",
      channel: channel
    }
  end

  def do_reply(:watch, {:failure, channel, reason}) do
    %{
      cmd: "s.system.watch",
      result: "failure",
      reason: reason,
      channel: channel
    }
  end

  def do_reply(:unwatch, {:ok, channel}) do
    %{
      cmd: "s.system.unwatch",
      result: "success",
      channel: channel
    }
  end

  def do_reply(:unwatch, {:failure, channel, reason}) do
    %{
      cmd: "s.system.unwatch",
      result: "failure",
      reason: reason,
      channel: channel
    }
  end

  def do_reply(:ring, ringer_id) do
    %{
      cmd: "s.system.ring",
      ringer_id: ringer_id
    }
  end

  def do_reply(:nouser, nil) do
    %{
      result: "error",
      error: "not logged in"
    }
  end

  def do_reply(:nolobby, nil) do
    %{
      result: "error",
      error: "not in a lobby"
    }
  end

  def do_reply(:noauth, nil) do
    %{
      result: "error",
      error: "no authorisation"
    }
  end

  def do_reply(:server_event, {:started, _}), do: nil
  def do_reply(:server_event, {event, node}) do
    %{
      cmd: "s.system.server_event",
      event: event,
      node: node
    }
  end

  def do_reply(:error, data) do
    %{
      result: "error",
      error: data.error,
      location: data.location
    }
  end
end
