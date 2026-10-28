defmodule Teiserver.Helpers.CacheHelper do
  @moduledoc false

  require Logger

  @spec cache_get(atom, any, any) :: any
  def cache_get(table, key, default \\ nil) do
    ConCache.get(table, key) || default
  catch
    :exit, :noproc ->
      Logger.warning("Cache #{table} is down (get)")
      default
  end

  @spec cache_get_or_store(atom, any, function) :: any
  def cache_get_or_store(table, key, func) do
    ConCache.get_or_store(table, key, func)
  catch
    :exit, :noproc ->
      Logger.warning("Cache #{table} is down (get_or_store)")
      func.()
  end

  @doc """
  Deletes the `key` from `table` across the entire cluster. Makes use of Phoenix.PubSub to do so.
  """
  @spec cache_delete(atom, any) :: :ok | {:error, any}
  def cache_delete(table, keys) when is_list(keys) do
    keys
    |> Enum.each(fn key ->
      ConCache.delete(table, key)
    end)

    Phoenix.PubSub.broadcast(
      Teiserver.PubSub,
      "cluster_hooks",
      {:cluster_hooks, :delete, Node.self(), table, keys}
    )
  catch
    :exit, :noproc ->
      # If the cache is down we don't need to delete stuff so this solves itself
      :ok
  end

  def cache_delete(table, key), do: cache_delete(table, [key])

  @doc """
  Puts the `value` into `key` for `table` across the entire cluster. Makes use of Phoenix.PubSub to do so.
  """
  @spec cache_put(atom, any, any) :: :ok | {:error, any}
  def cache_put(table, key, value) do
    ConCache.put(table, key, value)

    Phoenix.PubSub.broadcast(
      Teiserver.PubSub,
      "cluster_hooks",
      {:cluster_hooks, :put, Node.self(), table, key, value}
    )
  catch
    :exit, :noproc ->
      Logger.warning("Cache #{table} is down (put)")
  end

  @doc """
  Puts the `value` into `key` for `table` across the entire cluster. Makes use of Phoenix.PubSub to do so.
  """
  @spec cache_insert_new(atom, any, any) :: :ok | {:error, any}
  def cache_insert_new(table, key, value) do
    ConCache.insert_new(table, key, value)

    Phoenix.PubSub.broadcast(
      Teiserver.PubSub,
      "cluster_hooks",
      {:cluster_hooks, :insert_new, Node.self(), table, key, value}
    )
  end

  @doc """
  The first argument is passed through.

  If passed an `{:ok, value}` as the first argument it will store the value in
  the cache table under the key.

  If no key is provided the `id` of the value in the ok'd tuple will be used.
  """
  @spec cache_put_on_ok({:ok, any()} | any(), atom) :: {:ok, any()} | any()
  def cache_put_on_ok(result, table), do: cache_put_on_ok(result, table, nil)

  @spec cache_put_on_ok({:ok, any()} | any(), atom, any()) :: {:ok, any()} | any()
  def cache_put_on_ok({:ok, value}, table, key) do
    key = key || value.id
    cache_put(table, key, value)
    {:ok, value}
  end

  def cache_put_on_ok(error_value, _table, _key), do: error_value

  @doc """
  The first argument is passed through.

  If passed an `{:ok, value}` as the first argument it will delete the cached
  value for that table under that key.

  If no key is provided the `id` of the value in the ok'd tuple will be used.
  """
  @spec cache_delete_on_ok({:ok, any()} | any(), atom) :: {:ok, any()} | any()
  def cache_delete_on_ok(result, table), do: cache_delete_on_ok(result, table, nil)

  @spec cache_delete_on_ok({:ok, any()} | any(), atom, any()) :: {:ok, any()} | any()
  def cache_delete_on_ok({:ok, value}, table, key) do
    key = key || value.id
    cache_delete(table, key)
    {:ok, value}
  end

  def cache_delete_on_ok(error_value, _table, _key), do: error_value

  # Stores
  @spec store_get(atom, any) :: any
  def store_get(table, key), do: Teiserver.cache_get(table, key)

  @spec store_delete(atom, any) :: :ok
  def store_delete(table, key), do: ConCache.delete(table, key)

  @spec store_put(atom, any, any) :: :ok
  def store_put(table, key, value), do: ConCache.put(table, key, value)

  @spec store_insert_new(atom, any, any) :: :ok
  def store_insert_new(table, key, value), do: ConCache.put(table, key, value)

  @spec store_update(atom, any, function()) :: :ok
  def store_update(table, key, func), do: ConCache.update(table, key, func)

  @spec store_get_or_store(atom, any, function) :: any
  def store_get_or_store(table, key, func) do
    ConCache.get_or_store(table, key, func)
  end

  # Setup and supervisors
  def concache_sup(name, opts \\ []) do
    Supervisor.child_spec(
      {
        ConCache,
        [
          name: name,
          ttl_check_interval: 10_000,
          global_ttl: opts[:global_ttl] || 60_000,
          touch_on_read: true
        ]
      },
      id: {ConCache, name}
    )
  end

  def concache_perm_sup(name) do
    Supervisor.child_spec(
      {
        ConCache,
        [
          name: name,
          ttl_check_interval: false
        ]
      },
      id: {ConCache, name}
    )
  end
end
