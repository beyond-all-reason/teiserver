defmodule Teiserver.MetadataCache do
  @moduledoc """
  Cache and setup for miscellaneous metadata
  """

  alias Teiserver.Helpers.CacheHelper

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_arg) do
    children = [
      CacheHelper.concache_perm_sup(:application_metadata_cache)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
