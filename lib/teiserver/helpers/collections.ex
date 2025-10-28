defmodule Teiserver.Helpers.Collections do
  @doc """
  Helper to recursively transform maps. Useful to parse incoming tachyon data
  into internal structure and vice versa
  See tests in test/teiserver/tachyon/schema_test.exs for some examples.
  """
  def transform_map(nil, _mapping), do: nil

  def transform_map(data, mapping) do
    Enum.reduce(mapping, %{}, fn {source_key, spec}, m ->
      if is_map_key(data, source_key) do
        val = Map.get(data, source_key)

        case spec do
          k when is_atom(k) or is_binary(k) ->
            Map.put(m, k, val)

          f when is_function(f, 3) ->
            f.(m, source_key, val)

          f when is_function(f, 2) ->
            f.(m, val)

          {dest_key, mapping} ->
            cond do
              is_function(mapping, 1) -> Map.put(m, dest_key, mapping.(val))
              is_map(val) -> Map.put(m, dest_key, transform_map(val, mapping))
              is_list(val) -> Map.put(m, dest_key, Enum.map(val, &transform_map(&1, mapping)))
              true -> Map.put(m, dest_key, val)
            end
        end
      else
        m
      end
    end)
  end
end
