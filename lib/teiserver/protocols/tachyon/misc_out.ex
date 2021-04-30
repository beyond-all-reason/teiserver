defmodule Teiserver.Protocols.Tachyon.MiscOut do
  @spec do_reply(atom(), Map.t()) :: Map.t()
  def do_reply(:pong, _data) do
    %{
      cmd: "PONG"
    }
  end

  def do_reply(:error, data) do
    %{
      cmd: "ERROR",
      location: data.location,
      error: data.error
    }
  end
end
