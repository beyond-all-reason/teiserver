defmodule Teiserver.Bridge.DiscordSupervisor do
  @moduledoc false
  use Supervisor

  import Teiserver.Helpers.CacheHelper,
    only: [concache_sup: 1, concache_perm_sup: 1]

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    Supervisor.init(
      [
        concache_sup(:discord_bridge_dm_cache),
        concache_perm_sup(:discord_channel_cache),
        concache_perm_sup(:discord_command_cache),
        Nostrum.Application,
        Teiserver.Bridge.BridgeServer,
        Teiserver.Bridge.DiscordBridgeBot
      ],
      strategy: :rest_for_one
    )
  end
end
