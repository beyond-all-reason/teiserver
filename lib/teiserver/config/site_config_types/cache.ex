defmodule Teiserver.Config.SiteConfigTypes.Cache do
  @moduledoc """
  Cache and setup for site configuration
  """

  use Supervisor
  alias Teiserver.Helpers.CacheHelper

  def start_link(opts) do
    with {:ok, sup} <- Supervisor.start_link(__MODULE__, :ok, opts),
         :ok <- Teiserver.Config.SiteConfigTypes.SystemConfigs.create(),
         :ok <- Teiserver.TeiserverConfigs.teiserver_configs() do
      {:ok, sup}
    end
  end

  @impl true
  def init(:ok) do
    children = [
      CacheHelper.concache_perm_sup(:config_site_type_store),
      CacheHelper.concache_perm_sup(:config_site_cache)
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
