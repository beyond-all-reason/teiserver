defmodule Central.NestedMaps do
  @spec get(Map.t(), [String.t() | atom]) :: any
  def get(map, _path = [k | []]) do
    map[k]
  end

  def get(map, _path = [k | keys]) do
    get(map[k], keys)
  end

  @spec put(Map.t(), [String.t() | atom], any) :: Map.t()
  def put(map, _path = [k | []], value) do
    Map.put(map, k, value)
  end

  def put(map, _path = [k | keys], value) do
    Map.put(map, k, put(map[k], keys, value))
  end
end
