defmodule Central.NestedMaps do
  def get(map, [k | []]) do
    map[k]
  end

  def get(map, [k | keys]) do
    get(map[k], keys)
  end

  def put(map, [k | []], value) do
    Map.put(map, k, value)
  end

  def put(map, [k | keys], value) do
    Map.put(map, k, put(map[k], keys, value))
  end
end
