defmodule Teiserver.Tachyon.System do
  @moduledoc false

  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = [
      Teiserver.Tachyon.Schema.cache_spec(),
      Teiserver.Autohost.System,
      Teiserver.TachyonBattle.System,
      Teiserver.Matchmaking.System,
      Teiserver.TachyonLobby.System,
      Teiserver.Party.System,
      Teiserver.Player.System
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  restart the entire tachyon system
  """
  def restart() do
    :ok = Supervisor.terminate_child(Teiserver.Supervisor, __MODULE__)
    {:ok, _pid} = Supervisor.restart_child(Teiserver.Supervisor, __MODULE__)
  end

  @doc """
  Utility to restore state at startup. Given a store name, reads
  all corresponding blobs and call `module.function(blob.key, blob.value)`
  in an async manner for all of them.
  Then delete all these blobs (regardless of what happens during the restoration)
  """
  def restore_state(store_name, module, function) do
    blobs = Teiserver.KvStore.scan(store_name)
    Logger.info("Attempting to restore #{length(blobs)} from #{store_name}")

    try do
      n =
        Enum.map(blobs, fn b ->
          Task.async(fn -> apply(module, function, [b.key, b.value]) end)
        end)
        |> Task.await_many()
        |> Enum.count()

      Logger.info("Restored #{n} blobs from #{store_name} snapshots")
      :ok
    after
      Enum.map(blobs, fn b -> {b.store, b.key} end)
      |> Teiserver.KvStore.delete_many()
    end
  end
end
