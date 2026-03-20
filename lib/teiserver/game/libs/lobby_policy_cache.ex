defmodule Teiserver.Data.LobbyPolicyCache do
  @moduledoc """
  Define cache for lobby policies and set it up
  """

  alias Teiserver.Game
  alias Teiserver.Helpers.CacheHelper

  use Supervisor

  def start_link(opts) do
    with {:ok, sup} <- Supervisor.start_link(__MODULE__, :ok, opts) do
      Teiserver.cache_put(:lists, :lobby_policies, [])
      Game.pre_cache_policies()
      {:ok, sup}
    end
  end

  @impl Supervisor
  def init(:ok) do
    children = [
      CacheHelper.concache_perm_sup(:lobby_policies_cache)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
