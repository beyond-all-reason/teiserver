defmodule Teiserver.Telemetry.UnauthPropertyLib do
  use CentralWeb, :library
  alias Teiserver.Telemetry.UnauthProperty

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-???"
  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:default)

  # Queries
  @spec query_unauth_properties() :: Ecto.Query.t
  def query_unauth_properties do
    from unauth_properties in UnauthProperty
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
    from unauth_properties in query,
      where: unauth_properties.id == ^id
  end

  def _search(query, :name, name) do
    from unauth_properties in query,
      where: unauth_properties.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from unauth_properties in query,
      where: unauth_properties.id in ^id_list
  end

  def _search(query, :simple_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from unauth_properties in query,
      where: (
            ilike(unauth_properties.name, ^ref_like)
        )
  end

  def _search(query, :property_type_id, property_type_id) do
    from unauth_properties in query,
      where: unauth_properties.property_type_id == ^property_type_id
  end

  def _search(query, :between, {start_date, end_date}) do
    from unauth_properties in query,
      where: between(unauth_properties.last_updated, ^start_date, ^end_date)
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Name (A-Z)") do
    from unauth_properties in query,
      order_by: [asc: unauth_properties.name]
  end

  def order_by(query, "Name (Z-A)") do
    from unauth_properties in query,
      order_by: [desc: unauth_properties.name]
  end

  def order_by(query, "Newest first") do
    from unauth_properties in query,
      order_by: [desc: unauth_properties.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from unauth_properties in query,
      order_by: [asc: unauth_properties.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, preloads) do
    query = if :property_type in preloads, do: _preload_property_types(query), else: query
    query
  end

  def _preload_property_types(query) do
    from client_properties in query,
      left_join: property_types in assoc(client_properties, :property_type),
      preload: [property_type: property_types]
  end
end
