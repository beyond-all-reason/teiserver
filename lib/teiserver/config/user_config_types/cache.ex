defmodule Teiserver.Config.UserConfigTypes.Cache do
  @moduledoc """
  Cache and setup for profile configuration
  """

  use Supervisor
  alias Teiserver.Helpers.CacheHelper

  def start_link(opts) do
    with {:ok, sup} <- Supervisor.start_link(__MODULE__, :ok, opts),
         :ok <- Teiserver.Config.UserConfigTypes.ProfileConfigs.create(),
         :ok <- Teiserver.Config.UserConfigTypes.PrivacyConfigs.create() do
      {:ok, sup}
    end
  end

  @impl true
  def init(:ok) do
    children = [
      CacheHelper.concache_perm_sup(:config_user_type_store)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
