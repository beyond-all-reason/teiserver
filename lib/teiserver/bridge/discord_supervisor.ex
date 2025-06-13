defmodule Teiserver.Bridge.DiscordSupervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_) do
    Supervisor.init(
      [Nostrum.Application, Teiserver.Bridge.BridgeServer, Teiserver.Bridge.DiscordBridgeBot],
      strategy: :rest_for_one
    )
  end
end
