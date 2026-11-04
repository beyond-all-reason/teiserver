defmodule Teiserver.Helpers.DateValidations do
  @moduledoc """
    Date-related changeset validations.
  """
  import Ecto.Changeset
  @default_max_range 365

  @doc """
  Validates that the end field is not earlier than the start date.

  Adds an error to the `end_field` when the end date preceds start date. Equal dates are allowed.

  ## Options

  - `start_field` - Field containing the start date, defaults to `:start_date`
  - `end_field` - Field containing the end date, defaults to `:end_date`

  """
  @spec validate_date_order(Ecto.Changeset.t(), atom(), atom()) :: Ecto.Changeset.t()
  def validate_date_order(changeset, start_field \\ :start_date, end_field \\ :end_date) do
    start_date = get_field(changeset, start_field)
    end_date = get_field(changeset, end_field)

    if valid_dates?(start_date, end_date) and Date.compare(end_date, start_date) == :lt do
      add_error(
        changeset,
        end_field,
        "#{parse_atom(end_field)} cannot be set to earlier date than #{parse_atom(start_field)}."
      )
    else
      changeset
    end
  end

  @doc """
    Validates that the difference between two dates does not exceed `days`. Uses `Date.diff/2`.

    Unparsable strings and negative values fall back to the default of #{@default_max_range} days.

    Adds an error to `:base` when the difference exceeds `days`.

  ## Notes

    The error is attached to `:base` rather than a form field. This means templates must provide a way to render it.

    For example, in a LiveView template:

      <%= for {message, _opts} <- Keyword.get_values(@form.source.errors, :base) do %>
          <p class="text-sm text-rose-600">
            {message}
          </p>
      <% end %>

  """
  @spec validate_max_range(Ecto.Changeset.t(), binary() | integer(), atom(), atom()) ::
          Ecto.Changeset.t()
  def validate_max_range(changeset, days, start_field \\ :start_date, end_field \\ :end_date)

  def validate_max_range(changeset, days, start_field, end_field)
      when is_integer(days) and days >= 0 do
    start_date = get_field(changeset, start_field)
    end_date = get_field(changeset, end_field)

    if valid_dates?(start_date, end_date) and Date.diff(end_date, start_date) > days do
      add_error(changeset, :base, "Dates too far apart, max range is #{days} days.")
    else
      changeset
    end
  end

  def validate_max_range(changeset, days, start_field, end_field) when is_binary(days) do
    changeset
    |> validate_max_range(parse_max_range(days), start_field, end_field)
  end

  def validate_max_range(changeset, days, start_field, end_field) when is_integer(days) do
    changeset
    |> validate_max_range(@default_max_range, start_field, end_field)
  end

  @doc """
  Validates that a date field does not contain a future date.

  Adds an error to `field` when its value is later than the current UTC date.
  """
  @spec validate_date_not_in_future(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def validate_date_not_in_future(changeset, field) do
    date = get_field(changeset, field)

    if valid_date?(date) and Date.compare(date, Date.utc_today()) == :gt do
      add_error(changeset, field, "Cannot be set to a future date.")
    else
      changeset
    end
  end

  defp valid_date?(%Date{}), do: true
  defp valid_date?(_value), do: false

  defp valid_dates?(%Date{}, %Date{}), do: true
  defp valid_dates?(_value1, _value2), do: false

  defp parse_max_range(days) do
    case Integer.parse(days) do
      :error ->
        @default_max_range

      {int, ""} when int >= 0 ->
        int

      {_int, _rem} ->
        @default_max_range
    end
  end

  defp parse_atom(atom) do
    Atom.to_string(atom) |> String.split("_") |> Enum.join(" ") |> String.capitalize()
  end
end
