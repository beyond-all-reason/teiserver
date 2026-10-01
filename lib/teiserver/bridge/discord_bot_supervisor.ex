defmodule Teiserver.Bridge.DiscordBotSupervisor do
  @moduledoc """
  The supervisor for the bot processes used for Discord functionality.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    Supervisor.init(
      [
        Nostrum.Application,
        Teiserver.Bridge.BridgeServer,
        Teiserver.Bridge.DiscordBridgeBot
      ],
      strategy: :rest_for_one
    )
  end
end
