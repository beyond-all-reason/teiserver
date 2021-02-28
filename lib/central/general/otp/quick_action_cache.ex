defmodule Central.General.QuickAction.Cache do
  use GenServer

  @table_name :quick_action_cache

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def add_items(items) do
    GenServer.cast(__MODULE__, {:add, items})
  end

  def get_items() do
    case :ets.lookup(@table_name, :items) do
      [{:items, items}] -> items
      [] -> {:error, "Not found"}
    end
  end

  # GenServer callbacks
  def handle_cast({:add, items}, table) do
    existing =
      case :ets.lookup(@table_name, :items) do
        [] -> []
        [{_, v}] -> v
      end

    :ets.insert(table, {:items, existing ++ items})
    {:noreply, table}
  end

  def init(_args) do
    table = :ets.new(@table_name, [:named_table, read_concurrency: true])
    :ets.insert(table, {:items, []})
    {:ok, table}
  end
end
