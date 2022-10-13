defmodule Teiserver.Moderation.ActionLib do
  @moduledoc false
  use TeiserverWeb, :library
  alias Teiserver.Moderation.Action

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-triangle"

  @spec colour :: atom
  def colour, do: :primary

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(action) do
    %{
      type_colour: colour(),
      type_icon: icon(),

      item_id: action.id,
      item_type: "teiserver_moderation_action",
      item_colour: colour(),
      item_icon: icon(),
      item_label: "#{action.name}",

      url: "/moderation/actions/#{action.id}"
    }
  end

  # Queries
  @spec query_actions() :: Ecto.Query.t
  def query_actions do
    from actions in Action
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
    from actions in query,
      where: actions.id == ^id
  end

  def _search(query, :name, name) do
    from actions in query,
      where: actions.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from actions in query,
      where: actions.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from actions in query,
      where: (
            ilike(actions.name, ^ref_like)
        )
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Name (A-Z)") do
    from actions in query,
      order_by: [asc: actions.name]
  end

  def order_by(query, "Name (Z-A)") do
    from actions in query,
      order_by: [desc: actions.name]
  end

  def order_by(query, "Newest first") do
    from actions in query,
      order_by: [desc: actions.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from actions in query,
      order_by: [asc: actions.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from actions in query,
  #     left_join: things in assoc(actions, :things),
  #     preload: [things: things]
  # end
end
