defmodule Teiserver.Account.AutomodActionLib do
  use CentralWeb, :library
  alias Teiserver.Account.AutomodAction

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-circle-divide"

  @spec colours :: atom
  def colours, do: :danger

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(automod_action) do
    %{
      type_colour: StylingHelper.colours(colours()) |> elem(0),
      type_icon: icon(),

      item_id: automod_action.id,
      item_type: "teiserver_account_automod_action",
      item_colour: colours(),
      item_icon: Teiserver.Account.AutomodActionLib.icon(),
      item_label: "#{automod_action.type} - #{automod_action.user.name}",

      url: "/account/automod_actions/#{automod_action.id}"
    }
  end

  # Queries
  @spec query_automod_actions() :: Ecto.Query.t
  def query_automod_actions do
    from automod_actions in AutomodAction
  end

  @spec search(Ecto.Query.t, Map.t | nil) :: Ecto.Query.t
  def search(query, nil), do: query
  def search(query, params) do
    params
    |> Enum.reduce(query, fn ({key, value}, query_acc) ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t, Atom.t(), any()) :: Ecto.Query.t
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from automod_actions in query,
      where: automod_actions.id == ^id
  end

  def _search(query, :value, value) do
    from automod_actions in query,
      where: automod_actions.value == ^value
  end

  def _search(query, :enabled, enabled) do
    from automod_actions in query,
      where: automod_actions.enabled == ^enabled
  end

  def _search(query, :type, type) do
    from automod_actions in query,
      where: automod_actions.type == ^type
  end

  def _search(query, :id_list, id_list) do
    from automod_actions in query,
      where: automod_actions.id in ^id_list
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Newest first") do
    from automod_actions in query,
      order_by: [desc: automod_actions.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from automod_actions in query,
      order_by: [asc: automod_actions.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, preloads) do
    query = if :user in preloads, do: _preload_user(query), else: query
    query = if :added_by in preloads, do: _preload_added_by(query), else: query
    query
  end

  def _preload_user(query) do
    from automod_actions in query,
      left_join: user in assoc(automod_actions, :user),
      preload: [user: user]
  end

  def _preload_added_by(query) do
    from automod_actions in query,
      left_join: added_by in assoc(automod_actions, :added_by),
      preload: [added_by: added_by]
  end
end
