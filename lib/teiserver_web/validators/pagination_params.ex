defmodule TeiserverWeb.Validators.PaginationParams do
  @moduledoc """
  Centralized pagination parameter validation.
  Used by both the plug and LiveViews to ensure consistent validation logic.
  """

  # Maximum allowed limit to prevent abuse
  @max_limit 500

  @doc """
  Validates and clamps a limit value to prevent abuse.
  Returns a safe limit value between 1 and @max_limit.

    ## Examples

      validate_limit("100")  # => 100
      validate_limit("5000") # => 500 (clamped to max)
      validate_limit("0")    # => 50 (default)
      validate_limit(nil)    # => 50 (default)
  """
  def validate_limit(limit) when is_binary(limit) do
    case Integer.parse(limit) do
      {int_limit, ""} -> validate_limit(int_limit)
      # Default if parsing fails
      _ -> 50
    end
  end

  def validate_limit(limit) when is_integer(limit) do
    cond do
      limit <= 0 -> 50
      limit > @max_limit -> @max_limit
      true -> limit
    end
  end

  def validate_limit(_), do: 50

  def validate_page(nil), do: 1
  def validate_page(""), do: 1
  def validate_page(n) when is_integer(n), do: max(1, n)

  def validate_page(raw) when is_binary(raw) do
    case Integer.parse(raw) do
      {i, _} -> max(1, i)
      :error -> 1
    end
  end

  @doc """
  Validates page and limit parameters and returns a map with validated values.
  This is the main function that should be used by both plugs and LiveViews.
  """
  def validate_params(params) do
    %{
      limit: validate_limit(params["limit"]),
      page: validate_page(params["page"])
    }
  end
end
