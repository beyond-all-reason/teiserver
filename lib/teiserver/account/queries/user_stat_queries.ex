defmodule Teiserver.Account.UserStatQueries do
  @moduledoc false
  alias Ecto.Query
  alias Teiserver.Account.UserStat

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec user_stats() :: t()
  def user_stats do
    from(user_stats in UserStat, as: :user_stats)
  end

  @spec where_user_id(t(), pos_integer() | String.t()) :: t()
  def where_user_id(query, user_id) do
    from [user_stats: user_stats] in query,
      where: user_stats.user_id == ^user_id
  end

  def where_data_equal(query, _field, nil), do: query
  def where_data_equal(query, _field, ""), do: query

  def where_data_equal(query, field, value) do
    from [user_stats: user_stats] in query,
      where: fragment("? ->> ? = ?", user_stats.data, ^field, ^value)
  end

  def where_data_contains(query, _field, nil), do: query
  def where_data_contains(query, _field, ""), do: query

  def where_data_contains(query, field, value) do
    from [user_stats: user_stats] in query,
      where: fragment("? ->> ? @> ?", user_stats.data, ^field, ^value)
  end

  def where_data_like(query, _field, nil), do: query
  def where_data_like(query, _field, ""), do: query

  def where_data_like(query, field, value) do
    from [user_stats: user_stats] in query,
      where: like(fragment("(? ->> ?)::text", user_stats.data, ^field), ^(value <> "%"))
  end
end
