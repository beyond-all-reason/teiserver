defmodule Central do
  @moduledoc """
  Central is a starting point for making a Phoenix based application.
  """

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
      Central.PubSub,
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
      Central.PubSub,
      "cluster_hooks",
      {:cluster_hooks, :put, Node.self(), table, key, value}
    )
  end

  @doc """
  Puts the `value` into `key` for `table` across the entire cluster. Makes use of Phoenix.PubSub to do so.
  """
  @spec cache_update(atom, any, any) :: :ok | {:error, any}
  def cache_update(table, key, func) do
    ConCache.update(table, key, func)

    Phoenix.PubSub.broadcast(
      Central.PubSub,
      "cluster_hooks",
      {:cluster_hooks, :update, Node.self(), table, key, func}
    )
  end
end
