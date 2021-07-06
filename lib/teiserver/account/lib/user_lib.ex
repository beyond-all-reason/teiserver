defmodule Teiserver.Account.UserLib do
  use CentralWeb, :library
  alias Central.Account.UserQueries

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-user-robot"

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:success)

  @spec make_favourite(Central.Account.User.t()) :: Map.t()
  def make_favourite(user) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),
      item_id: user.id,
      item_type: "teiserver_user",
      item_colour: user.colour,
      item_icon: user.icon,
      item_label: "#{user.name}",
      url: "/teiserver/admin/user/#{user.id}"
    }
  end

  # Queries
  @spec get_user() :: Ecto.Query.t()
  def get_user, do: UserQueries.get_users()

  @spec search(Ecto.Query.t(), map | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), atom, any) :: Ecto.Query.t()
  def _search(query, _, "Any"), do: query

  def _search(query, :exact_name, value) do
    from users in query,
      where: users.name == ^value
  end

  def _search(query, :bot, "Person") do
    from users in query,
      where: fragment("? ->> ? = ?", users.data, "bot", "false")
  end

  def _search(query, :bot, "Robot") do
    from users in query,
      where: fragment("? ->> ? = ?", users.data, "bot", "true")
  end

  def _search(query, :moderator, "User") do
    from users in query,
      where: fragment("? ->> ? = ?", users.data, "moderator", "false")
  end

  def _search(query, :moderator, "Moderator") do
    from users in query,
      where: fragment("? ->> ? = ?", users.data, "moderator", "true")
  end

  def _search(query, :verified, "Unverified") do
    from users in query,
      where: fragment("? ->> ? = ?", users.data, "verified", "false")
  end

  def _search(query, :verified, "Verified") do
    from users in query,
      where: fragment("? ->> ? = ?", users.data, "verified", "true")
  end

  def _search(query, :donor, "Donor") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Donor\"")
  end

  def _search(query, :donor, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Donor\"")
  end

  def _search(query, :contributor, "Contributor") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Contributor\"")
  end

  def _search(query, :contributor, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Contributor\"")
  end

  def _search(query, :developer, "Developer") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Developer\"")
  end

  def _search(query, :developer, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Developer\"")
  end

  def _search(query, key, value) do
    UserQueries._search(query, key, value)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query
  def order_by(query, key), do: UserQueries.order(query, key)

  @spec preload(Ecto.Query.t(), list() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = UserQueries.preload(query, preloads)

    # query = if :skills in preloads, do: _preload_skills(query), else: query

    query
  end

  # def _preload_skills(query) do
  #   from user in query,
  #     left_join: skills in assoc(user, :horizon_skills),
  #     preload: [horizon_skills: skills]
  # end
end
