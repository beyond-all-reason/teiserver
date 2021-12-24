defmodule Teiserver.Account.AccoladeLib do
  use CentralWeb, :library
  alias Teiserver.Account.Accolade

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-award"

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:info)

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(accolade) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),

      item_id: accolade.id,
      item_type: "teiserver_account_accolade",
      item_colour: colours() |> elem(0),
      item_icon: Teiserver.Account.AccoladeLib.icon(),
      item_label: "#{accolade.name}",

      url: "/account/accolades/#{accolade.id}"
    }
  end

  # Queries
  @spec query_accolades() :: Ecto.Query.t
  def query_accolades do
    from accolades in Accolade
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
    from accolades in query,
      where: accolades.id == ^id
  end

  def _search(query, :name, name) do
    from accolades in query,
      where: accolades.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from accolades in query,
      where: accolades.id in ^id_list
  end

  def _search(query, :simple_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from accolades in query,
      where: (
            ilike(accolades.name, ^ref_like)
        )
  end

  def _search(query, :filter, "all"), do: query
  def _search(query, :filter, {"all", _}), do: query

  def _search(query, :filter, {"recipient", user_id}) do
    from reports in query,
      where: reports.recipient_id == ^user_id
  end

  def _search(query, :filter, {"giver", user_id}) do
    from reports in query,
      where: reports.giver_id == ^user_id
  end

  def _search(query, :filter, {"badge_type", type_id}) do
    from reports in query,
      where: reports.badge_type_id == ^type_id
  end

  def _search(query, :user_id, user_id) do
    from reports in query,
      where: (reports.giver_id == ^user_id or reports.recipient_id == ^user_id)
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Name (A-Z)") do
    from accolades in query,
      order_by: [asc: accolades.name]
  end

  def order_by(query, "Name (Z-A)") do
    from accolades in query,
      order_by: [desc: accolades.name]
  end

  def order_by(query, "Newest first") do
    from accolades in query,
      order_by: [desc: accolades.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from accolades in query,
      order_by: [asc: accolades.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from accolades in query,
  #     left_join: things in assoc(accolades, :things),
  #     preload: [things: things]
  # end
end
