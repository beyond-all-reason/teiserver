defmodule Teiserver.Moderation.BanLib do
  @moduledoc false
  use TeiserverWeb, :library
  alias Teiserver.Moderation.Ban

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-gavel"

  @spec colour :: atom
  def colour, do: :danger

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(ban) do
    %{
      type_colour: colour(),
      type_icon: icon(),

      item_id: ban.id,
      item_type: "teiserver_moderation_ban",
      item_colour: colour(),
      item_icon: icon(),
      item_label: "#{ban.name}",

      url: "/moderation/bans/#{ban.id}"
    }
  end

  # Queries
  @spec query_bans() :: Ecto.Query.t
  def query_bans do
    from bans in Ban
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
    from bans in query,
      where: bans.id == ^id
  end

  def _search(query, :name, name) do
    from bans in query,
      where: bans.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from bans in query,
      where: bans.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from bans in query,
      where: (
            ilike(bans.name, ^ref_like)
        )
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Name (A-Z)") do
    from bans in query,
      order_by: [asc: bans.name]
  end

  def order_by(query, "Name (Z-A)") do
    from bans in query,
      order_by: [desc: bans.name]
  end

  def order_by(query, "Newest first") do
    from bans in query,
      order_by: [desc: bans.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from bans in query,
      order_by: [asc: bans.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from bans in query,
  #     left_join: things in assoc(bans, :things),
  #     preload: [things: things]
  # end
end
