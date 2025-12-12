defmodule Teiserver.Moderation.BanLib do
  @moduledoc false
  use TeiserverWeb, :library
  alias Teiserver.Moderation.Ban

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-gavel"

  @spec colour :: atom
  def colour, do: :danger

  @spec make_favourite(map()) :: map()
  def make_favourite(ban) do
    %{
      type_colour: colour(),
      type_icon: icon(),
      item_id: ban.id,
      item_type: "teiserver_moderation_ban",
      item_colour: colour(),
      item_icon: icon(),
      item_label: "#{ban.source.name}",
      url: "/moderation/bans/#{ban.id}"
    }
  end

  # Queries
  @spec query_bans() :: Ecto.Query.t()
  def query_bans do
    from(bans in Ban)
  end

  @spec search(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from bans in query,
      where: bans.id == ^id
  end

  def _search(query, :id_list, id_list) do
    from bans in query,
      where: bans.id in ^id_list
  end

  def _search(query, :source_id, source_id) do
    from bans in query,
      where: bans.source_id == ^source_id
  end

  def _search(query, :enabled, enabled) do
    from bans in query,
      where: bans.enabled == ^enabled
  end

  def _search(query, :any_key, key_list) do
    from bans in query,
      where: array_overlap_a_in_b(bans.key_values, ^key_list)
  end

  def _search(query, :source_id_in, id_list) do
    from bans in query,
      where: bans.source_id in ^id_list
  end

  def _search(query, :added_before, dt) do
    from bans in query,
      where: bans.inserted_at < ^dt
  end

  def _search(query, :name, name) do
    from bans in query,
      left_join: sources in assoc(bans, :source),
      where: ilike(sources.name, ^"%#{name}%")
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from bans in query,
      left_join: sources in assoc(bans, :source),
      order_by: [asc: sources.name]
  end

  def order_by(query, "Name (Z-A)") do
    from bans in query,
      left_join: sources in assoc(bans, :source),
      order_by: [desc: sources.name]
  end

  def order_by(query, "Newest first") do
    from bans in query,
      order_by: [desc: bans.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from bans in query,
      order_by: [asc: bans.inserted_at]
  end

  @spec preload(Ecto.Query.t(), list() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :source in preloads, do: _preload_source(query), else: query
    query = if :adder in preloads, do: _preload_adder(query), else: query
    query
  end

  @spec _preload_source(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_source(query) do
    from bans in query,
      left_join: sources in assoc(bans, :source),
      preload: [source: sources]
  end

  @spec _preload_adder(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_adder(query) do
    from bans in query,
      left_join: adders in assoc(bans, :added_by),
      preload: [added_by: adders]
  end
end
