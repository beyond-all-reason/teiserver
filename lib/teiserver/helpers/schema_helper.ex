defmodule Teiserver.Helper.SchemaHelper do
  @moduledoc false

  @spec trim_strings(map(), List.t()) :: map()
  def trim_strings(params, names) do
    names = Enum.map(names, fn n -> Atom.to_string(n) end)

    params
    |> Map.new(fn {k, v} ->
      case Enum.member?(names, k) do
        true ->
          case v do
            nil ->
              {k, nil}

            _value ->
              {k, String.trim(v)}
          end

        false ->
          {k, v}
      end
    end)
  end

  @spec min_and_max(map(), [atom]) :: map()
  def min_and_max(params, [field1, field2]) do
    field1 = Atom.to_string(field1)
    field2 = Atom.to_string(field2)

    value1 = params[field1] || ""
    value2 = params[field2] || ""

    mapped_values =
      cond do
        value1 == "" or value2 == "" -> %{}
        value1 > value2 -> %{field1 => value2, field2 => value1}
        true -> %{}
      end

    Map.merge(params, mapped_values)
  end

  @spec uniq_lists(map(), List.t()) :: map()
  def uniq_lists(params, names) do
    names = Enum.map(names, fn n -> Atom.to_string(n) end)

    params
    |> Map.new(fn {k, v} ->
      case Enum.member?(names, k) do
        true ->
          case v do
            nil ->
              {k, nil}

            _value ->
              {k, Enum.uniq(v)}
          end

        false ->
          {k, v}
      end
    end)
  end

  @spec remove_whitespace(map(), List.t()) :: map()
  def remove_whitespace(params, names) do
    names = Enum.map(names, fn n -> Atom.to_string(n) end)

    params
    |> Map.new(fn {k, v} ->
      case Enum.member?(names, k) do
        true ->
          case v do
            nil ->
              {k, nil}

            _value ->
              {
                k,
                v
                |> String.replace(" ", "")
                |> String.replace("\t", "")
                |> String.replace("\n", "")
              }
          end

        false ->
          {k, v}
      end
    end)
  end

  @doc """
  Given a list of fields and a list of patterns, will apply Regex.replace for every
  pattern to each field.
  """
  @spec remove_characters(map(), List.t(), List.t()) :: map()
  def remove_characters(params, names, patterns) do
    names = Enum.map(names, fn n -> Atom.to_string(n) end)

    params
    |> Map.new(fn {k, v} ->
      case Enum.member?(names, k) do
        true ->
          case v do
            nil ->
              {k, nil}

            _value ->
              new_value =
                patterns
                |> Enum.reduce(v, fn pattern, acc ->
                  Regex.replace(pattern, acc, "")
                end)

              {
                k,
                new_value
              }
          end

        false ->
          {k, v}
      end
    end)
  end
end
