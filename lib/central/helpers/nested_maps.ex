defmodule Central.NestedMaps do
  @moduledoc false
  @spec get(Map.t(), [String.t() | atom]) :: any
  def get(map, [k | []] = _path) do
    map[k]
  end

  def get(map, [k | keys] = _path) do
    get(map[k], keys)
  end

  @spec put(Map.t(), [String.t() | atom], any) :: Map.t()
  def put(map, [k | []] = _path, value) do
    Map.put(map || %{}, k, value)
  end

  def put(map, [k | keys] = _path, value) do
    Map.put(map || %{}, k, put(map[k] || %{}, keys, value))
  end
end
