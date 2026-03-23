defmodule Teiserver.Helper.SchemaHelper do
  @moduledoc false

  import Ecto.Changeset, only: [get_field: 2]

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

  def parse_humantimes(params, names) do
    names = Enum.map(names, fn n -> Atom.to_string(n) end)

    params
    |> Map.new(fn {k, v} ->
      case Enum.member?(names, k) do
        true ->
          case v do
            nil ->
              {k, nil}

            %DateTime{} = d ->
              {k, d}

            _value ->
              case HumanTime.relative(v) do
                {:ok, ht_v} ->
                  {k, ht_v}

                {:error, _reason} ->
                  # We need to do this replace to stop "invalid string" appearing multiple times
                  {k, String.replace(v, " - Invalid format", "") <> " - Invalid format"}
              end
          end

        false ->
          {k, v}
      end
    end)
  end

  # @spec validate_human_time(map, list | atom, Keyword.t) :: t
  def validate_human_time(changeset, fields) when not is_nil(fields) do
    %{required: required, errors: errors, changes: changes} = changeset
    message = "Invalid format"
    fields = List.wrap(fields)

    fields_with_errors =
      for field <- fields,
          ht_valid?(changeset, field),
          ensure_field_exists!(changeset, field),
          is_nil(errors[field]),
          do: field

    case fields_with_errors do
      [] ->
        %{changeset | required: fields ++ required}

      _fields ->
        new_errors = Enum.map(fields_with_errors, &{&1, {message, [human_time: :invalid]}})
        changes = Map.drop(changes, fields_with_errors)

        %{
          changeset
          | changes: changes,
            required: fields ++ required,
            errors: new_errors ++ errors,
            valid?: false
        }
    end
  end

  defp ensure_field_exists!(%{types: types, data: data}, field) do
    if !Map.has_key?(types, field) do
      raise ArgumentError, "unknown field #{inspect(field)} in #{inspect(data)}"
    end

    true
  end

  defp ht_valid?(changeset, field) when is_atom(field) do
    case get_field(changeset, field) do
      nil ->
        false

      v ->
        case HumanTime.relative(v) do
          {:error, _reason} -> true
          {:ok, _result} -> false
        end
    end
  end
end
