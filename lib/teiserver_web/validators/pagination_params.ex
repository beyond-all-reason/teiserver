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

  @doc """
  Validates page and limit parameters and returns a map with validated values.
  This is the main function that should be used by both plugs and LiveViews.
  """
  def validate_params(params) do
    page =
      if not is_nil(params["page"]) do
        case Integer.parse(params["page"]) do
          {int, _} -> int |> max(1)
          # Some pages like the phoenix live dashboard can user string "page" params (e.g. "home") which can't be parsed as integers
          :error -> params["page"]
        end
      end

    %{
      limit: validate_limit(params["limit"] || "50"),
      page: page
    }
  end
end
