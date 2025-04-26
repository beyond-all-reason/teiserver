defmodule Teiserver.Bridge.DiscordSystem do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    children =
      if Teiserver.Communication.use_discord?() do
        [Teiserver.Bridge.DiscordSupervisor]
      else
        []
      end

    Supervisor.init(children,
      restart: :temporary,
      strategy: :rest_for_one
    )
  end
end
