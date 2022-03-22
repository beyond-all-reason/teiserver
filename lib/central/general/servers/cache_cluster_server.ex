defmodule Central.General.CacheClusterServer do
  use GenServer
  alias Phoenix.PubSub

  @spec start_link(list) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @impl true
  def handle_info({:cluster_hooks, :delete, from_node, table, keys}, state) do
    if from_node != Node.self() do
      keys
      |> Enum.each(fn key ->
        delete_key(table, key)
      end)
    end
    {:noreply, state}
  end

  defp delete_key(table, key) do
    ConCache.delete(table, key)
  end

  @impl true
  @spec init(any) :: {:ok, %{}}
  def init(_) do
    :ok = PubSub.subscribe(Central.PubSub, "cluster_hooks")
    {:ok, %{}}
  end
end
