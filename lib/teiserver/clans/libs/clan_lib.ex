defmodule Teiserver.Clans.ClanLib do
  use TeiserverWeb, :library
  alias Teiserver.Clans.Clan

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-globe"

  @spec colours :: atom
  def colours, do: :info2

  @spec make_favourite(Clan.t()) :: map()
  def make_favourite(clan) do
    %{
      type_colour: StylingHelper.colours(colours()) |> elem(0),
      type_icon: icon(),
      item_id: clan.id,
      item_type: "teiserver_clans_clan",
      item_colour: clan.colour,
      item_icon: clan.icon,
      item_label: "#{clan.name}",
      url: "/clans/#{clan.id}"
    }
  end

  @spec ranks :: [String.t()]
  def ranks, do: ~w(Admin Moderator Member)

  # Queries
  @spec query_clans() :: Ecto.Query.t()
  def query_clans do
    from(clans in Clan)
  end

  @spec search(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from clans in query,
      where: clans.id == ^id
  end

  def _search(query, :name, name) do
    from clans in query,
      where: clans.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from clans in query,
      where: clans.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from clans in query,
      where: ilike(clans.name, ^ref_like)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from clans in query,
      order_by: [asc: clans.name]
  end

  def order_by(query, "Name (Z-A)") do
    from clans in query,
      order_by: [desc: clans.name]
  end

  def order_by(query, "Newest first") do
    from clans in query,
      order_by: [desc: clans.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from clans in query,
      order_by: [asc: clans.inserted_at]
  end

  @spec preload(Ecto.Query.t(), list() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :members in preloads, do: _preload_members(query), else: query

    query =
      if :members_and_memberships in preloads,
        do: _preload_members_and_memberships(query),
        else: query

    query =
      if :invites_and_invitees in preloads, do: _preload_invites_and_invitees(query), else: query

    query
  end

  def _preload_members(query) do
    from clans in query,
      left_join: members in assoc(clans, :members),
      order_by: [asc: members.name],
      limit: 50,
      preload: [members: members]
  end

  def _preload_members_and_memberships(query) do
    from clans in query,
      left_join: memberships in assoc(clans, :memberships),
      left_join: users in assoc(memberships, :user),
      order_by: [asc: users.name],
      limit: 50,
      preload: [memberships: {memberships, user: users}]
  end

  def _preload_invites_and_invitees(query) do
    from clans in query,
      left_join: invites in assoc(clans, :invites),
      left_join: users in assoc(invites, :user),
      order_by: [asc: users.name],
      limit: 50,
      preload: [invites: {invites, user: users}]
  end

  # def _preload_things(query) do
  #   from clans in query,
  #     left_join: things in assoc(clans, :things),
  #     preload: [things: things]
  # end
end
