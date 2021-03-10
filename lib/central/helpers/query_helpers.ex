defmodule Central.Helpers.QueryHelpers do
  alias Central.Repo
  import Ecto.Query, warn: false

  defmacro stddev_pop(field) do
    quote do
      fragment("stddev_pop(?)", unquote(field))
    end
  end

  defmacro between(field, low, high) do
    quote do
      fragment("? BETWEEN ? AND ?", unquote(field), unquote(low), unquote(high))
    end
  end

  defmacro array_remove(field, value) do
    quote do
      fragment("array_remove(?, ?)", unquote(field), unquote(value))
    end
  end

  defmacro array_agg(field) do
    quote do
      fragment("array_agg(?)", unquote(field))
    end
  end

  defmacro extract_year(field) do
    quote do
      fragment("EXTRACT(YEAR FROM ?)", unquote(field))
    end
  end

  defmacro extract_month(field) do
    quote do
      fragment("EXTRACT(MONTH FROM ?)", unquote(field))
    end
  end

  defmacro extract_week(field) do
    quote do
      fragment("EXTRACT(WEEK FROM ?)", unquote(field))
    end
  end

  defmacro extract_hour(field) do
    quote do
      fragment("EXTRACT(HOUR FROM ?)", unquote(field))
    end
  end

  defmacro date_trunc(period, field) do
    quote do
      fragment("date_trunc(?, ?)", unquote(period), unquote(field))
    end
  end

  def count(table) do
    Repo.aggregate(table, :count, :id)
  end

  def offset_query(query, amount) do
    query
    |> offset(^amount)
  end

  def limit_query(query, amount) do
    query
    |> limit(^amount)
  end

  @spec limit_query(Ecto.Query.t(), integer() | nil, integer() | nil) :: Ecto.Query.t()
  def limit_query(query, nil, max_amount), do: limit_query(query, max_amount)

  def limit_query(query, amount, max_amount) when is_integer(amount) do
    limit_query(query, min(amount, max_amount))
  end

  def limit_query(query, amount, max_amount) do
    limit_query(query, min(amount |> String.to_integer(), max_amount))
  end

  @spec select(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def select(query, nil), do: query

  def select(query, fields) do
    from stat_grids in query,
      select: ^fields
  end
end
