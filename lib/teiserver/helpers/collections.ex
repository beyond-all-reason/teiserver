defmodule Teiserver.Helpers.Collections do
  @moduledoc false
  @doc """
  Helper to recursively transform maps. Useful to parse incoming tachyon data
  into internal structure and vice versa
  See tests in Teiserver.Helpers.CollectionsTest for some examples.
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
            transform_keyval(m, mapping, dest_key, val)

          {dest_key, struct_module, mapping} ->
            result = transform_keyval(m, mapping, dest_key, val)

            Map.update!(result, dest_key, fn val ->
              if is_list(val),
                do: Enum.map(val, &struct(struct_module, &1)),
                else: struct!(struct_module, val)
            end)
        end
      else
        m
      end
    end)
  end

  defp transform_keyval(data, mapping, dest_key, val) do
    cond do
      is_function(mapping, 1) -> Map.put(data, dest_key, mapping.(val))
      is_map(val) -> Map.put(data, dest_key, transform_map(val, mapping))
      is_list(val) -> Map.put(data, dest_key, Enum.map(val, &transform_map(&1, mapping)))
      true -> Map.put(data, dest_key, val)
    end
  end

  @doc """
  recursively traverse a map and produce a map without any nil value
  """
  def remove_nil_vals(map) do
    Enum.map(map, fn {k, v} ->
      if is_map(v),
        do: {k, remove_nil_vals(v)},
        else: {k, v}
    end)
    |> Enum.filter(&(elem(&1, 1) != nil))
    |> Map.new()
  end

  def zip_with_padding(enum1, enum2, padding, acc \\ []) do
    case {enum1, enum2} do
      {[], []} -> :lists.reverse(acc)
      {[], [x | rest]} -> zip_with_padding([], rest, padding, [{padding, x} | acc])
      {[x | rest], []} -> zip_with_padding(rest, [], padding, [{x, padding} | acc])
      {[x | rest1], [y | rest2]} -> zip_with_padding(rest1, rest2, padding, [{x, y} | acc])
    end
  end
end
