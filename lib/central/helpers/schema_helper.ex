defmodule Central.Helpers.SchemaHelper do
  @moduledoc false

  # import Central.Helpers.NumberHelper, only: [dec_parse: 1]
  import Ecto.Changeset, only: [get_field: 2]

  defp make_date(d) do
    %{
      "day" => Integer.to_string(d.day),
      "month" => Integer.to_string(d.month),
      "year" => Integer.to_string(d.year)
    }
  end

  @spec make_datetime(Datetime.t()) :: Map.t()
  defp make_datetime(d) do
    %{
      "second" => Integer.to_string(d.second),
      "day" => Integer.to_string(d.day),
      "hour" => Integer.to_string(d.hour),
      "minute" => Integer.to_string(d.minute),
      "month" => Integer.to_string(d.month),
      "year" => Integer.to_string(d.year)
    }
  end

  @spec parse_datetimes(Map.t(), List.t()) :: Map.t()
  def parse_datetimes(params, names) do
    names = Enum.map(names, fn n -> Atom.to_string(n) end) ++ names

    params
    |> Map.new(fn {k, v} ->
      cond do
        not Enum.member?(names, k) ->
          {k, v}

        is_map(v) ->
          {k, v}

        String.trim(v) == "" ->
          {k, v}

        true ->
          cond do
            # Regex.match?(@date_timestamp, v) ->
            String.contains?(v, "T") ->
              d = Timex.parse!(v, "{YYYY}-{0M}-{0D}T{h24}:{m}")
              {k, make_datetime(d)}

            String.contains?(v, "/") ->
              d = Timex.parse!(v, "{h24}:{m}:{s} {0D}/{0M}/{YYYY}")
              {k, make_datetime(d)}

            String.contains?(v, "-") ->
              d = Timex.parse!(v, "{YYYY}-{0M}-{0D} {h24}:{m}:{s}")
              {k, make_datetime(d)}
          end
      end
    end)
  end

  def parse_dates(params, names) do
    names = Enum.map(names, fn n -> Atom.to_string(n) end) ++ names

    params
    |> Enum.map(fn {k, v} ->
      cond do
        Enum.member?(names, k) and is_map(v) ->
          {k, v}
        Enum.member?(names, k) and v == nil ->
          {k, v}
        Enum.member?(names, k) and String.trim(v) == "" ->
          {k, v}
        Enum.member?(names, k) ->
          d = case String.length(v) do
            8 -> Timex.parse!(v, "{0D}/{0M}/{YY}")
            _ -> Timex.parse!(v, "{0D}/{0M}/{YYYY}")
          end
          {k, make_date(d)}
        true ->
          {k, v}
      end
    end)
    |> Map.new
  end

  # def parse_currency(params, names) do
  #   names = Enum.map(names, fn n -> Atom.to_string(n) end)

  #   params
  #   |> Enum.map(fn {k, v} ->
  #     case Enum.member?(names, k) do
  #       true -> {k, dec_parse(v)}
  #       false -> {k, v}
  #     end
  #   end)
  #   |> Map.new
  # end

  # def parse_string_list(nil), do: []
  # def parse_string_list(params, names) do
  #   names = Enum.map(names, fn n -> Atom.to_string(n) end)

  #   params
  #   |> Enum.map(fn {k, v} ->
  #     case Enum.member?(names, k) do
  #       true ->
  #         case v do
  #           nil -> {k, nil}
  #           _ -> {
  #             k,
  #             v
  #             |> String.split("\n")
  #             |> Enum.map(&String.trim/1)
  #           }
  #         end

  #       false -> {k, v}
  #     end
  #   end)
  #   |> Map.new
  # end

  @spec trim_strings(Map.t(), List.t()) :: Map.t()
  def trim_strings(params, names) do
    names = Enum.map(names, fn n -> Atom.to_string(n) end)

    params
    |> Map.new(fn {k, v} ->
      case Enum.member?(names, k) do
        true ->
          case v do
            nil ->
              {k, nil}

            _ ->
              {k, String.trim(v)}
          end

        false ->
          {k, v}
      end
    end)
  end

  @spec remove_whitespace(Map.t(), List.t()) :: Map.t()
  def remove_whitespace(params, names) do
    names = Enum.map(names, fn n -> Atom.to_string(n) end)

    params
    |> Map.new(fn {k, v} ->
      case Enum.member?(names, k) do
        true ->
          case v do
            nil ->
              {k, nil}

            _ ->
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
  @spec remove_characters(Map.t(), List.t(), List.t()) :: Map.t()
  def remove_characters(params, names, patterns) do
    names = Enum.map(names, fn n -> Atom.to_string(n) end)

    params
    |> Map.new(fn {k, v} ->
      case Enum.member?(names, k) do
        true ->
          case v do
            nil ->
              {k, nil}

            _ ->
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

  @spec safe_strings(Map.t(), List.t()) :: Map.t()
  def safe_strings(params, names) do
    names = Enum.map(names, fn n -> Atom.to_string(n) end)

    params
    |> Map.new(fn {k, v} ->
      case Enum.member?(names, k) do
        true ->
          case v do
            nil ->
              {k, nil}

            _ ->
              {
                k,
                v
                |> String.replace(" ", "_")
                |> String.downcase()
              }
          end

        false ->
          {k, v}
      end
    end)
  end

  def parse_checkboxes(params, names) do
    names = Enum.map(names, fn n -> Atom.to_string(n) end)

    adjusted_params =
      names
      |> Enum.map(fn k ->
        {k, if(params[k] == "true" or params[k] == true, do: true, else: false)}
      end)
      |> Map.new()

    Map.merge(params, adjusted_params)
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

            _ ->
              case HumanTime.relative(v) do
                {:ok, ht_v} ->
                  {k, ht_v}

                {:error, _} ->
                  # We need to do this replace to stop "invalid string" appearing multiple times
                  {k, String.replace(v, " - Invalid string", "") <> " - Invalid string"}
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
    message = "Unable to convert"
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

      _ ->
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
    unless Map.has_key?(types, field) do
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
          {:error, _} -> true
          {:ok, _} -> false
        end
    end
  end
end
