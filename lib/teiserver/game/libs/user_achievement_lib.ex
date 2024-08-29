defmodule Teiserver.Game.UserAchievementLib do
  use TeiserverWeb, :library
  alias Teiserver.Game.UserAchievement

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-star"

  @spec colour :: atom
  def colour, do: :info2

  @spec make_favourite(map()) :: map()
  def make_favourite(user_achievement) do
    %{
      type_colour: colour(),
      type_icon: icon(),
      item_id: user_achievement.id,
      item_type: "teiserver_account_user_achievement",
      item_colour: colour(),
      item_icon: icon(),
      item_label: "#{user_achievement.name}",
      url: "/account/user_achievements/#{user_achievement.id}"
    }
  end

  # Queries
  @spec query_user_achievements() :: Ecto.Query.t()
  def query_user_achievements do
    from(user_achievements in UserAchievement)
  end

  @spec search(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), Atom.t(), any()) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :user_id, user_id) do
    from user_achievements in query,
      where: user_achievements.user_id == ^user_id
  end

  def _search(query, :user_id_in, user_ids) when is_list(user_ids) do
    from user_achievements in query,
      where: user_achievements.user_id in ^user_ids
  end

  def _search(query, :type_id, type_id) do
    from user_achievements in query,
      where: user_achievements.achievement_type_id == ^type_id
  end

  def _search(query, :type_id_in, type_ids) when is_list(type_ids) do
    from user_achievements in query,
      where: user_achievements.achievement_type_id in ^type_ids
  end

  def _search(query, :achieved, achieved) do
    from user_achievements in query,
      where: user_achievements.achieved == ^achieved
  end

  def _search(query, :inserted_after, date) do
    from user_achievements in query,
      where: user_achievements.inserted_at > ^date
  end

  def _search(query, :inserted_before, date) do
    from user_achievements in query,
      where: user_achievements.inserted_at < ^date
  end

  def _search(query, :name, name) do
    from user_achievements in query,
      where: user_achievements.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from user_achievements in query,
      where: user_achievements.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from user_achievements in query,
      where: ilike(user_achievements.name, ^ref_like)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from user_achievements in query,
      order_by: [asc: user_achievements.name]
  end

  def order_by(query, "Name (Z-A)") do
    from user_achievements in query,
      order_by: [desc: user_achievements.name]
  end

  def order_by(query, "Newest first") do
    from user_achievements in query,
      order_by: [desc: user_achievements.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from user_achievements in query,
      order_by: [asc: user_achievements.inserted_at]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :achievement_type in preloads, do: _preload_achievement_type(query), else: query
    query
  end

  def _preload_achievement_type(query) do
    from user_achievements in query,
      left_join: achievement_types in assoc(user_achievements, :achievement_type),
      preload: [achievement_type: achievement_types]
  end
end
