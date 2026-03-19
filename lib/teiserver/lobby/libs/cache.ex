defmodule Teiserver.Lobby.Cache do
  @moduledoc """
  Cache for lobby cache
  """

  use Supervisor
  alias Teiserver.Helpers.CacheHelper
  alias Teiserver.Lobby.CommandLib

  def start_link(opts) do
    with {:ok, sup} <- Supervisor.start_link(__MODULE__, :ok, opts),
         :ok <- CommandLib.cache_lobby_commands() do
      {:ok, sup}
    end
  end

  @impl Supervisor
  def init(:ok) do
    children = [
      CacheHelper.concache_perm_sup(:lobby_command_cache)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
