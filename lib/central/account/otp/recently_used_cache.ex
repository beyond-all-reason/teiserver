defmodule Central.Account.RecentlyUsedCache do
  use GenServer

  @table_name :central_recently_used_cache
  @recently_used_limit 50

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, @table_name, opts)
  end

  def remove_recently(item) do
    GenServer.cast(__MODULE__, {:remove, item})
  end

  def remove_recently(item, conn) do
    item
    |> Map.merge(%{
      user_id: conn.assigns[:current_user].id
    })
    |> remove_recently
  end

  def insert_recently(item) do
    GenServer.cast(__MODULE__, {:insert, item})
  end

  def insert_recently(item, conn) do
    item
    |> Map.merge(%{
      user_id: conn.assigns[:current_user].id
    })
    |> insert_recently

    item
  end

  def get_recently(%{assigns: %{current_user: current_user}}) do
    get_recently(current_user.id)
  end

  def get_recently(user_id) do
    case :ets.lookup(@table_name, user_id) do
      [{^user_id, data}] -> data
      [] -> []
    end
  end

  # GenServer callbacks
  def handle_cast({:insert, item}, table) do
    user_id = item.user_id

    existing =
      case :ets.lookup(@table_name, item.user_id) do
        [{^user_id, data}] -> data
        [] -> []
      end

    new_items =
      existing
      |> Enum.filter(fn r ->
        r.item_id != item.item_id or r.item_type != item.item_type
      end)
      |> Enum.take(@recently_used_limit)

    :ets.insert(table, {item.user_id, [item] ++ new_items})
    {:noreply, table}
  end

  def handle_cast({:remove, item}, table) do
    user_id = item.user_id

    existing =
      case :ets.lookup(@table_name, item.user_id) do
        [{^user_id, data}] -> data
        [] -> []
      end

    new_items =
      existing
      |> Enum.filter(fn r ->
        r.item_id != item.item_id or r.item_type != item.item_type
      end)

    :ets.insert(table, {item.user_id, new_items})
    {:noreply, table}
  end

  def init(_) do
    table = :ets.new(@table_name, [:named_table, read_concurrency: true])
    {:ok, table}
  end
end
