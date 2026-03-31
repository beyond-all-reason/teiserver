defmodule Teiserver.Bridge.DiscordSupervisor do
  @moduledoc false
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    Supervisor.init(
      [Nostrum.Application, Teiserver.Bridge.BridgeServer, Teiserver.Bridge.DiscordBridgeBot],
      strategy: :rest_for_one,
      max_restarts: 5,
      max_seconds: 60
    )
  end
end
