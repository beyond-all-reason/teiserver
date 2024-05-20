defmodule Teiserver.Tachyon.Cache do
  @moduledoc """
  Cache for tachyon schemas and dispatchers
  """

  use Supervisor
  alias Teiserver.Helpers.CacheHelper

  def start_link(opts) do
    with {:ok, sup} <- Supervisor.start_link(__MODULE__, :ok, opts),
         {:ok, _schemas} <- Teiserver.Tachyon.Schema.load_schemas(),
         :ok <- Teiserver.Tachyon.CommandDispatch.build_dispatch_cache() do
      {:ok, sup}
    end
  end

  @impl true
  def init(:ok) do
    children = [
      CacheHelper.concache_perm_sup(:tachyon_schemas),
      CacheHelper.concache_perm_sup(:tachyon_dispatches)
    ]

    # we could have schema and dispatches under their own supervision tree each
    # and their own init, but this is simpler
    Supervisor.init(children, strategy: :one_for_all)
  end
end
