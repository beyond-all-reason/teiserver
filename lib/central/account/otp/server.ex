defmodule Central.Account.AuthGroups.Server do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :permissions_cache, opts)
  end

  def get_all do
    GenServer.call(__MODULE__, {:get_all})
  end

  def add(module, section, permissions) do
    GenServer.cast(__MODULE__, {:add, module, section, permissions})
  end

  def lookup(module, section) do
    case :ets.lookup(:permissions_cache, {module, section}) do
      [{{^module, ^section}, permissions}] -> {:ok, permissions}
      [] -> :error
    end
  end

  # GenServer callbacks
  def handle_call({:get_all}, _from, {table, permission_state}) do
    {:reply, permission_state, {table, permission_state}}
  end

  def handle_cast({:add, module, section, permissions}, {table, permission_state}) do
    permission_state = Map.put(permission_state, {module, section}, permissions)
    :ets.insert(table, {{module, section}, permissions})
    {:noreply, {table, permission_state}}
  end

  def init(table_name) do
    table = :ets.new(table_name, [:named_table, read_concurrency: true])
    permissions = %{}
    {:ok, {table, permissions}}
  end
end
