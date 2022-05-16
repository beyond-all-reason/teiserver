defmodule Teiserver.Protocols.Tachyon.V1.SystemOut do
  @spec do_reply(atom(), any) :: Map.t()
  def do_reply(:pong, _data) do
    %{
      cmd: "s.system.pong",
      time: System.system_time(:second)
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

  def do_reply(:nobattle, nil) do
    %{
      result: "error",
      error: "not in a battle"
    }
  end

  def do_reply(:noauth, nil) do
    %{
      result: "error",
      error: "no authorisation"
    }
  end

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
