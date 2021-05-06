defmodule Teiserver.Protocols.Tachyon.SystemOut do
  @spec do_reply(atom(), any) :: Map.t()
  def do_reply(:pong, _data) do
    %{
      cmd: "s.system.pong"
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
