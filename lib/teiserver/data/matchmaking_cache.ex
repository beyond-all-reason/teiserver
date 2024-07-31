defmodule Teiserver.Data.MatchmakingCache do
  @moduledoc """
  Define cache for matchmaking and set it up
  """

  use Supervisor
  alias Teiserver.Helpers.CacheHelper

  def start_link(opts) do
    with {:ok, sup} <- Supervisor.start_link(__MODULE__, :ok, opts) do
      Teiserver.cache_put(:lists, :rooms, [])
      Teiserver.Data.Matchmaking.pre_cache_queues()

      {:ok, sup}
    end
  end

  @impl true
  def init(:ok) do
    children = [
      CacheHelper.concache_perm_sup(:teiserver_queues)
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
