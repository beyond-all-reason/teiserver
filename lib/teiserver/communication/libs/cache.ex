defmodule Teiserver.Communication.Cache do
  @moduledoc """
  Cache and setup for communication stuff
  """

  use Supervisor
  alias Teiserver.Helpers.CacheHelper

  def start_link(opts) do
    with {:ok, sup} <- Supervisor.start_link(__MODULE__, :ok, opts),
         :ok <- Teiserver.Communication.build_text_callback_cache() do
      {:ok, sup}
    end
  end

  @impl true
  def init(:ok) do
    children = [
      CacheHelper.concache_perm_sup(:text_callback_trigger_lookup),
      CacheHelper.concache_perm_sup(:text_callback_store)
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
