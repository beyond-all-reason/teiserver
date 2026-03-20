defmodule Teiserver.Config.UserConfigTypes.Cache do
  @moduledoc """
  Cache and setup for profile configuration
  """

  alias Teiserver.Config.UserConfigTypes.PrivacyConfigs
  alias Teiserver.Config.UserConfigTypes.ProfileConfigs
  alias Teiserver.Helpers.CacheHelper

  use Supervisor

  def start_link(opts) do
    with {:ok, sup} <- Supervisor.start_link(__MODULE__, :ok, opts),
         :ok <- ProfileConfigs.create(),
         :ok <- PrivacyConfigs.create() do
      {:ok, sup}
    end
  end

  @impl Supervisor
  def init(:ok) do
    children = [
      CacheHelper.concache_perm_sup(:config_user_type_store)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
