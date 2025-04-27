defmodule Teiserver.Helpers.Bimap do
  @moduledoc """
  A wrapper aroud a map where each value has 2 keys.
  Ensure that both keys are kept in sync.
  When storing another value and one of the key overlaps with an existing key,
  it deletes the previous keys before storing the new value.

  Typical usage: storing a reference from Process.monitor with some data
  about what the reference is about.

  bimap = Bimap.put(Bimap.new(), key1, key2, val)
  Bimap.get(bimap, key1) == val
  Bimap.get(bimap, key2) == val

  Bimap.delete(key1) == Bimap.new()
  Bimap.delete(key2) == Bimap.new()
  """

  @opaque t :: map()

  def new(), do: Map.new()

  def put(map, key1, key2, value) do
    case {Map.has_key?(map, key1), Map.has_key?(map, key2)} do
      {false, false} ->
        map |> Map.put(key2, {:key2, key1}) |> Map.put(key1, {:val, key2, value})

      {true, true} ->
        map |> Map.put(key2, {:key2, key1}) |> Map.put(key1, {:val, key2, value})

      {false, true} ->
        case Map.get(map, key2) do
          {:val, k2, _} ->
            map
            |> Map.delete(k2)
            |> Map.put(key2, {:key2, key1})
            |> Map.put(key1, {:val, key2, value})

          {:key2, k1} ->
            map
            |> Map.delete(k1)
            |> Map.put(key2, {:key2, key1})
            |> Map.put(key1, {:val, key2, value})
        end

      {true, false} ->
        case Map.get(map, key1) do
          {:val, k2, _} ->
            map
            |> Map.delete(k2)
            |> Map.put(key2, {:key2, key1})
            |> Map.put(key1, {:val, key2, value})

          {:key2, k1} ->
            map
            |> Map.delete(k1)
            |> Map.put(key2, {:key2, key1})
            |> Map.put(key1, {:val, key2, value})
        end
    end
  end

  def get(map, key) do
    case Map.get(map, key) do
      nil -> nil
      {:val, _, val} -> val
      {:key2, k} -> get(map, k)
    end
  end

  def get_other_key(map, key) do
    case Map.get(map, key) do
      nil -> nil
      {:val, k, _val} -> k
      {:key2, k} -> k
    end
  end

  def delete(map, key) do
    case Map.get(map, key) do
      nil -> map
      {:val, k, _v} -> Map.delete(map, k) |> Map.delete(key)
      {:key2, key1} -> Map.delete(map, key1) |> Map.delete(key)
    end
  end

  defdelegate has_key?(map, key), to: Map
end
