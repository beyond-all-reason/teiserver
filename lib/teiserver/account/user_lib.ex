defmodule Teiserver.Account.UserLib do
  use CentralWeb, :library
  alias Central.Account.UserQueries

  # Functions
  def icon, do: "far fa-user-tie"
  def colours, do: Central.Helpers.StylingHelper.colours(:success)

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
  @spec get_user() :: Ecto.Query.t
  def get_user, do: UserQueries.get_users

  @spec search(Ecto.Query.t, Map.t | nil) :: Ecto.Query.t
  def search(query, nil), do: query
  def search(query, params) do
    params
    |> Enum.reduce(query, fn ({key, value}, query_acc) ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, key, value) do
    UserQueries._search(query, key, value)
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, key), do: UserQueries.order(query, key)

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
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