defmodule Teiserver.Helpers.CacheHelper do
  @moduledoc """

  """

  @spec cache_get(atom, any) :: any
  def cache_get(table, key), do: ConCache.get(table, key)

  @spec cache_get_or_store(atom, any, function) :: any
  def cache_get_or_store(table, key, func) do
    ConCache.get_or_store(table, key, func)
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
  Puts the `value` into `key` for `table` across the entire cluster. Makes use of Phoenix.PubSub to do so.
  """
  @spec cache_update(atom, any, any) :: :ok | {:error, any}
  def cache_update(table, key, func) do
    ConCache.update(table, key, func)

    Phoenix.PubSub.broadcast(
      Teiserver.PubSub,
      "cluster_hooks",
      {:cluster_hooks, :update, Node.self(), table, key, func}
    )
  end

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
