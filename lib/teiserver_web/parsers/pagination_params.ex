defmodule TeiserverWeb.Parsers.PaginationParams do
  @moduledoc """
  Centralized pagination parameter parsing.
  Used by both the plug and LiveViews to ensure consistent parsing logic.
  """

  # Maximum allowed limit to prevent abuse
  @max_limit 500

  @doc """
  Parses and clamps a limit value to prevent abuse.
  Returns a safe limit value between 1 and @max_limit.

    ## Examples

      parse_limit("100")  # => 100
      parse_limit("5000") # => 500 (clamped to max)
      parse_limit("0")    # => 50 (default)
      parse_limit(nil)    # => 50 (default)
  """
  def parse_limit(limit) when is_binary(limit) do
    case Integer.parse(limit) do
      {int_limit, ""} -> parse_limit(int_limit)
      # Default if parsing fails
      _ -> 50
    end
  end

  def parse_limit(limit) when is_integer(limit) do
    cond do
      limit <= 0 -> 50
      limit > @max_limit -> @max_limit
      true -> limit
    end
  end

  def parse_limit(_), do: 50

  def parse_page(nil), do: 1
  def parse_page(""), do: 1
  def parse_page(n) when is_integer(n), do: max(1, n)

  def parse_page(raw) when is_binary(raw) do
    case Integer.parse(raw) do
      {i, _} -> max(1, i)
      :error -> 1
    end
  end

  @doc """
  Parses page and limit parameters and returns a map with parsed values.
  This is the main function that should be used by both plugs and LiveViews.
  """
  def parse_params(params) do
    %{
      limit: parse_limit(params["limit"]),
      page: parse_page(params["page"])
    }
  end
end
