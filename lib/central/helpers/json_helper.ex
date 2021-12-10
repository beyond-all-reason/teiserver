defmodule Central.Helpers.JsonHelper do
  @moduledoc false
  @spec json_cast(map, list) :: map
  def json_cast(object, fields) when is_list(fields) do
    fields
    |> Enum.map(fn f -> {f, Map.get(object, f)} end)
    |> Map.new()
  end

  def json_cast(objects, function) do
    objects
    |> Enum.map(function)
  end

  @spec diff(map, map) :: map
  def diff(original, new) do
    # First we get the key combos
    original_keys = Map.keys(original) |> Enum.map(&to_string/1)
    new_keys = Map.keys(new || %{})

    added_keys =
      new_keys
      |> Enum.filter(fn k ->
        not Enum.member?(original_keys, k) or
          Enum.member?([[], nil, ""], Map.get(original, k |> String.to_atom()))
      end)

    deleted_keys =
      original_keys
      |> Enum.filter(fn k -> not Enum.member?(new_keys, k) end)

    dual_keys =
      original_keys
      |> Enum.filter(fn k -> Enum.member?(new_keys, k) end)

    # Find changes in values
    value_diffs =
      dual_keys
      |> Enum.map(fn k ->
        ok = Map.get(original, k |> String.to_atom())
        nk = Map.get(new, k)

        {k, diff_key(ok, nk)}
      end)
      |> Map.new()

    differences =
      value_diffs
      |> Enum.map(fn {_k, is_diff} ->
        if is_map(is_diff) do
          is_diff.different
        else
          is_diff
        end
      end)
      |> Enum.filter(fn d -> d end)

    # Return our findings
    %{
      added_keys: added_keys,
      deleted_keys: deleted_keys,
      dual_keys: dual_keys,
      value_diffs: value_diffs,
      original: original,
      new: new,
      different: Enum.count(added_keys) + Enum.count(deleted_keys) + Enum.count(differences) > 0
    }
  end

  @spec diff_key(String.t(), String.t()) :: boolean
  @spec diff_key(integer, integer) :: boolean
  @spec diff_key(map, map) :: map
  @spec diff_key(list, list) :: map
  defp diff_key(original, new) when is_map(original) do
    diff(original, new)
  end

  defp diff_key([], []) do
    %{
      added_values: [],
      deleted_values: [],
      dual_values: [],
      different: false,
      simple: true
    }
  end

  defp diff_key([], new) do
    if is_map(hd(new)) do
      diff_key_list_complex([], new)
    else
      diff_key_list_simple([], new)
    end
  end

  defp diff_key(original, new) when is_list(original) do
    if is_map(hd(original)) do
      diff_key_list_complex(original, new)
    else
      diff_key_list_simple(original, new)
    end
  end

  defp diff_key(original, new) do
    original != new
  end

  @spec diff_key_list_simple(Map.t(), Map.t()) :: Map.t()
  defp diff_key_list_simple(original, new) do
    added_values =
      new
      |> Enum.filter(fn k -> not Enum.member?(original, k) end)

    deleted_values =
      original
      |> Enum.filter(fn k -> not Enum.member?(new, k) end)

    dual_values =
      original
      |> Enum.filter(fn k -> Enum.member?(new, k) end)

    %{
      added_values: added_values,
      deleted_values: deleted_values,
      dual_values: dual_values,
      different: Enum.count(added_values) + Enum.count(deleted_values) > 0,
      simple: true
    }
  end

  @spec diff_key_list_complex(Map.t(), Map.t()) :: Map.t()
  defp diff_key_list_complex(original, new) do
    converted_values =
      original
      |> Enum.map(fn v ->
        for {key, val} <- v, into: %{}, do: {to_string(key), val}
      end)

    diff_key_list_simple(converted_values, new)
    |> Map.put(:simple, false)
  end
end
