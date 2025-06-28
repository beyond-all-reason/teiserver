defmodule Teiserver.Account.RatingLib do
  @moduledoc """
  This module purely deals with functions around Teiserver.Account.Rating, it is not
  the module used for balance or ratings.
  """

  use TeiserverWeb, :library
  alias Teiserver.Account.{Rating}
  require Logger

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-chart-column"

  @spec colours :: atom
  def colours, do: :info

  # Queries
  @spec query_ratings() :: Ecto.Query.t()
  def query_ratings do
    from(ratings in Rating)
  end

  @spec search(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :user_id, user_id) do
    from ratings in query,
      where: ratings.user_id == ^user_id
  end

  def _search(query, :user_id_in, id_list) do
    from ratings in query,
      where: ratings.user_id in ^id_list
  end

  def _search(query, :rating_type_id, rating_type_id) do
    from ratings in query,
      where: ratings.rating_type_id == ^rating_type_id
  end

  def _search(query, :rating_type_id_in, id_list) do
    from ratings in query,
      where: ratings.rating_type_id in ^id_list
  end

  def _search(query, :updated_after, datetime) do
    from ratings in query,
      where: ratings.last_updated > ^datetime
  end

  def _search(query, :season, season) do
    from ratings in query,
      where: ratings.season == ^season
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Rating value high to low") do
    from ratings in query,
      order_by: [desc: ratings.rating_value]
  end

  def order_by(query, "Rating value low to high") do
    from ratings in query,
      order_by: [asc: ratings.rating_value]
  end

  def order_by(query, "Leaderboard rating high to low") do
    from ratings in query,
      order_by: [desc: ratings.leaderboard_rating]
  end

  def order_by(query, "Leaderboard rating low to high") do
    from ratings in query,
      order_by: [asc: ratings.leaderboard_rating]
  end

  def order_by(query, "Skill high to low") do
    from ratings in query,
      order_by: [desc: ratings.skill]
  end

  def order_by(query, "Skill low to high") do
    from ratings in query,
      order_by: [asc: ratings.skill]
  end

  def order_by(query, "Uncertainty high to low") do
    from ratings in query,
      order_by: [desc: ratings.uncertainty]
  end

  def order_by(query, "Uncertainty low to high") do
    from ratings in query,
      order_by: [asc: ratings.uncertainty]
  end

  def order_by(query, "Last updated new to old") do
    from ratings in query,
      order_by: [desc: ratings.last_updated]
  end

  def order_by(query, "Last updated old to new") do
    from ratings in query,
      order_by: [asc: ratings.last_updated]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :user in preloads, do: _preload_user(query), else: query
    query = if :rating_type in preloads, do: _preload_rating_type(query), else: query
    query
  end

  @spec _preload_user(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_user(query) do
    from ratings in query,
      left_join: users in assoc(ratings, :user),
      preload: [user: users]
  end

  @spec _preload_rating_type(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_rating_type(query) do
    from ratings in query,
      left_join: rating_types in assoc(ratings, :rating_type),
      preload: [rating_type: rating_types]
  end
end
