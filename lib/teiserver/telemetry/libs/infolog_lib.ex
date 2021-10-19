defmodule Teiserver.Telemetry.InfologLib do
  use CentralWeb, :library
  alias Teiserver.Telemetry.Infolog

  # Functions
  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: Central.Helpers.StylingHelper.colours(:info2)

  @spec icon() :: String.t()
  def icon(), do: "far fa-sliders-up"

  # Queries
  @spec query_infologs() :: Ecto.Query.t
  def query_infologs do
    from infologs in Infolog
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
    from infologs in query,
      where: infologs.id == ^id
  end

  def _search(query, :log_type, log_type) do
    from infologs in query,
      where: infologs.log_type == ^log_type
  end

  def _search(query, :user_id, user_id) do
    from infologs in query,
      where: infologs.user_id == ^user_id
  end

  def _search(query, :id_list, id_list) do
    from infologs in query,
      where: infologs.id in ^id_list
  end

  def _search(query, :between, {start_date, end_date}) do
    from infologs in query,
      where: between(infologs.timestamp, ^start_date, ^end_date)
  end

  def _search(query, :simple_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from infologs in query,
      where: (
            ilike(infologs.name, ^ref_like)
        )
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Newest first") do
    from infologs in query,
      order_by: [desc: infologs.timestamp]
  end

  def order_by(query, "Oldest first") do
    from infologs in query,
      order_by: [asc: infologs.timestamp]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, preloads) do
    query = if :user in preloads, do: _preload_users(query), else: query
    query
  end

  def _preload_users(query) do
    from infologs in query,
      left_join: users in assoc(infologs, :user),
      preload: [user: users]
  end
end
