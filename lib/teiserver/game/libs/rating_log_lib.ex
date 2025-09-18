defmodule Teiserver.Game.RatingLogLib do
  use TeiserverWeb, :library
  alias Teiserver.Game.RatingLog

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-list-alt"

  @spec colours :: atom
  def colours, do: :primary2

  @spec make_favourite(RatingLog.t()) :: map()
  def make_favourite(queue) do
    %{
      type_colour: StylingHelper.colours(colours()) |> elem(0),
      type_icon: icon(),
      item_id: queue.id,
      item_type: "teiserver_game_queue",
      item_colour: queue.colour,
      item_icon: queue.icon,
      item_label: "#{queue.name}",
      url: "/teiserver/admin/rating_logs/#{queue.id}"
    }
  end

  # Queries
  @spec query_rating_logs() :: Ecto.Query.t()
  def query_rating_logs do
    from(rating_logs in RatingLog)
  end

  @spec search(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), atom, any()) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from rating_logs in query,
      where: rating_logs.id == ^id
  end

  def _search(query, :user_id, user_id) do
    from rating_logs in query,
      where: rating_logs.user_id == ^user_id
  end

  def _search(query, :match_id, match_id) do
    from rating_logs in query,
      where: rating_logs.match_id == ^match_id
  end

  def _search(query, :rating_type_id, rating_type_id) do
    from rating_logs in query,
      where: rating_logs.rating_type_id == ^rating_type_id
  end

  def _search(query, :id_in, id_list) do
    from rating_logs in query,
      where: rating_logs.id in ^id_list
  end

  def _search(query, :user_id_in, user_id_list) do
    from rating_logs in query,
      where: rating_logs.user_id in ^user_id_list
  end

  def _search(query, :match_id_in, match_id_list) do
    from rating_logs in query,
      where: rating_logs.match_id in ^match_id_list
  end

  def _search(query, :rating_type_id_in, rating_type_id_list) do
    from rating_logs in query,
      where: rating_logs.rating_type_id in ^rating_type_id_list
  end

  def _search(query, :inserted_after, datetime) do
    from rating_logs in query,
      where: rating_logs.inserted_at > ^datetime
  end

  def _search(query, :inserted_before, datetime) do
    from rating_logs in query,
      where: rating_logs.inserted_at < ^datetime
  end

  def _search(query, :season, season) do
    from rating_logs in query,
      where: rating_logs.season == ^season
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from rating_logs in query,
      where: ilike(rating_logs.name, ^ref_like)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from rating_logs in query,
      order_by: [desc: rating_logs.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from rating_logs in query,
      order_by: [asc: rating_logs.inserted_at]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :match in preloads, do: _preload_match(query), else: query
    query = if :match_membership in preloads, do: _preload_match_membership(query), else: query
    query
  end

  @spec _preload_match(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_match(query) do
    from rating_logs in query,
      left_join: matches in assoc(rating_logs, :match),
      preload: [match: matches]
  end

  @spec _preload_match_membership(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_match_membership(query) do
    from rating_logs in query,
      left_join: match_memberships in Teiserver.Battle.MatchMembership,
      on: match_memberships.match_id == rating_logs.match_id,
      where:
        match_memberships.user_id == rating_logs.user_id and
          match_memberships.match_id == rating_logs.match_id,
      preload: [match_membership: match_memberships]
  end
end
