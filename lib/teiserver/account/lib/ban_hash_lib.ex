defmodule Teiserver.Account.BanHashLib do
  use CentralWeb, :library
  alias Teiserver.Account.BanHash

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-ban"

  @spec colours :: atom
  def colours, do: :danger

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(ban_hash) do
    %{
      type_colour: StylingHelper.colours(colours()) |> elem(0),
      type_icon: icon(),

      item_id: ban_hash.id,
      item_type: "teiserver_account_ban_hash",
      item_colour: colours() |> elem(0),
      item_icon: Teiserver.Account.BanHashLib.icon(),
      item_label: "#{ban_hash.type} - #{ban_hash.user.name}",

      url: "/account/ban_hashes/#{ban_hash.id}"
    }
  end

  # Queries
  @spec query_ban_hashes() :: Ecto.Query.t
  def query_ban_hashes do
    from ban_hashes in BanHash
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
    from ban_hashes in query,
      where: ban_hashes.id == ^id
  end

  def _search(query, :value, value) do
    from ban_hashes in query,
      where: ban_hashes.value == ^value
  end

  def _search(query, :type, type) do
    from ban_hashes in query,
      where: ban_hashes.type == ^type
  end

  def _search(query, :id_list, id_list) do
    from ban_hashes in query,
      where: ban_hashes.id in ^id_list
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Newest first") do
    from ban_hashes in query,
      order_by: [desc: ban_hashes.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from ban_hashes in query,
      order_by: [asc: ban_hashes.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, preloads) do
    query = if :user in preloads, do: _preload_user(query), else: query
    query = if :added_by in preloads, do: _preload_added_by(query), else: query
    query
  end

  def _preload_user(query) do
    from ban_hashes in query,
      left_join: user in assoc(ban_hashes, :user),
      preload: [user: user]
  end

  def _preload_added_by(query) do
    from ban_hashes in query,
      left_join: added_by in assoc(ban_hashes, :added_by),
      preload: [added_by: added_by]
  end
end
