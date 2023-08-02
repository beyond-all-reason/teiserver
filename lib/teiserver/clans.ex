defmodule Teiserver.Clans do
  @moduledoc """
  The Clans context.
  """

  import Ecto.Query, warn: false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo

  alias Teiserver.Clans.Clan
  alias Teiserver.Clans.ClanLib

  def clan_query(args) do
    clan_query(nil, args)
  end

  def clan_query(id, args) do
    ClanLib.query_clans()
    |> ClanLib.search(%{id: id})
    |> ClanLib.search(args[:search])
    |> ClanLib.preload(args[:preload])
    |> ClanLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of clans.

  ## Examples

      iex> list_clans()
      [%Clan{}, ...]

  """
  def list_clans(args \\ []) do
    clan_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single clan.

  Raises `Ecto.NoResultsError` if the Clan does not exist.

  ## Examples

      iex> get_clan!(123)
      %Clan{}

      iex> get_clan!(456)
      ** (Ecto.NoResultsError)

  """
  def get_clan!(id) when not is_list(id) do
    Central.cache_get_or_store(:teiserver_clan_cache_bang, id, fn ->
      clan_query(id, [])
      |> Repo.one!()
    end)
  end

  def get_clan!(args) do
    clan_query(nil, args)
    |> Repo.one!()
  end

  def get_clan!(id, args) do
    clan_query(id, args)
    |> Repo.one!()
  end

  @doc """
  Gets a single clan.

  Returns `nil` if the Clan does not exist.

  ## Examples

      iex> get_clan(123)
      %Clan{}

      iex> get_clan(456)
      nil

  """
  def get_clan(nil), do: nil
  def get_clan(id), do: get_clan(id, [])

  def get_clan(nil, _), do: nil

  def get_clan(id, args) when not is_list(id) do
    clan_query(id, args)
    |> Repo.one()
  end

  @doc """
  Creates a clan.

  ## Examples

      iex> create_clan(%{field: value})
      {:ok, %Clan{}}

      iex> create_clan(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_clan(attrs \\ %{}) do
    %Clan{}
    |> Clan.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a clan.

  ## Examples

      iex> update_clan(clan, %{field: new_value})
      {:ok, %Clan{}}

      iex> update_clan(clan, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_clan(%Clan{} = clan, attrs) do
    Central.cache_delete(:teiserver_clan_cache_bang, clan.id)

    clan
    |> Clan.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Clan.

  ## Examples

      iex> delete_clan(clan)
      {:ok, %Clan{}}

      iex> delete_clan(clan)
      {:error, %Ecto.Changeset{}}

  """
  def delete_clan(%Clan{} = clan) do
    Repo.delete(clan)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking clan changes.

  ## Examples

      iex> change_clan(clan)
      %Ecto.Changeset{source: %Clan{}}

  """
  def change_clan(%Clan{} = clan) do
    Clan.changeset(clan, %{})
  end

  alias Teiserver.Clans.ClanInvite
  alias Teiserver.Clans.ClanInviteLib

  @doc """
  Returns the list of clan_invites.

  ## Examples

      iex> list_clan_invites()
      [%Location{}, ...]

  """
  def list_clan_invites_by_clan(clan_id, args \\ []) do
    ClanInviteLib.get_clan_invites()
    |> ClanInviteLib.search(clan_id: clan_id)
    |> ClanInviteLib.search(args[:search])
    |> ClanInviteLib.preload(args[:joins])
    # |> ClanInviteLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
    |> Repo.all()
  end

  def list_clan_invites_by_user(user_id, args \\ []) do
    ClanInviteLib.get_clan_invites()
    |> ClanInviteLib.search(user_id: user_id)
    |> ClanInviteLib.search(args[:search])
    |> ClanInviteLib.preload(args[:joins])
    # |> ClanInviteLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
    |> Repo.all()
  end

  @doc """
  Gets a single clan_invite.

  Raises `Ecto.NoResultsError` if the ClanInvite does not exist.

  ## Examples

      iex> get_clan_invite!(123)
      %ClanInvite{}

      iex> get_clan_invite!(456)
      ** (Ecto.NoResultsError)

  """
  def get_clan_invite!(clan_id, user_id) do
    ClanInviteLib.get_clan_invites()
    |> ClanInviteLib.search(%{clan_id: clan_id, user_id: user_id})
    |> Repo.one!()
  end

  def get_clan_invite(clan_id, user_id) do
    ClanInviteLib.get_clan_invites()
    |> ClanInviteLib.search(%{clan_id: clan_id, user_id: user_id})
    |> Repo.one()
  end

  @doc """
  Creates a clan_invite.

  ## Examples

      iex> create_clan_invite(%{field: value})
      {:ok, %ClanInvite{}}

      iex> create_clan_invite(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_clan_invite(attrs) do
    %ClanInvite{}
    |> ClanInvite.changeset(attrs)
    |> Repo.insert()
  end

  def create_clan_invite(clan_id, user_id) do
    %ClanInvite{}
    |> ClanInvite.changeset(%{
      clan_id: clan_id,
      user_id: user_id
    })
    |> Repo.insert()
  end

  @doc """
  Updates a ClanInvite.

  ## Examples

      iex> update_clan_invite(clan_invite, %{field: new_value})
      {:ok, %Ruleset{}}

      iex> update_clan_invite(clan_invite, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_clan_invite(%ClanInvite{} = clan_invite, attrs) do
    clan_invite
    |> ClanInvite.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ClanInvite.

  ## Examples

      iex> delete_clan_invite(clan_invite)
      {:ok, %ClanInvite{}}

      iex> delete_clan_invite(clan_invite)
      {:error, %Ecto.Changeset{}}

  """
  def delete_clan_invite(%ClanInvite{} = clan_invite) do
    Repo.delete(clan_invite)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking clan_invite changes.

  ## Examples

      iex> change_clan_invite(clan_invite)
      %Ecto.Changeset{source: %ClanInvite{}}

  """
  def change_clan_invite(%ClanInvite{} = clan_invite) do
    ClanInvite.changeset(clan_invite, %{})
  end

  alias Teiserver.Clans.ClanMembership
  alias Teiserver.Clans.ClanMembershipLib

  @doc """
  Returns the list of clan_memberships.

  ## Examples

      iex> list_clan_memberships()
      [%Location{}, ...]

  """
  def list_clan_memberships_by_clan(clan_id, args \\ []) do
    ClanMembershipLib.get_clan_memberships()
    |> ClanMembershipLib.search(clan_id: clan_id)
    |> ClanMembershipLib.search(args[:search])
    |> ClanMembershipLib.preload(args[:joins])
    # |> ClanMembershipLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
    |> Repo.all()
  end

  def list_clan_memberships_by_user(user_id, args \\ []) do
    ClanMembershipLib.get_clan_memberships()
    |> ClanMembershipLib.search(user_id: user_id)
    |> ClanMembershipLib.search(args[:search])
    |> ClanMembershipLib.preload(args[:joins])
    # |> ClanMembershipLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
    |> Repo.all()
  end

  @doc """
  Gets a single clan_membership.

  Raises `Ecto.NoResultsError` if the ClanMembership does not exist.

  ## Examples

      iex> get_clan_membership!(123)
      %ClanMembership{}

      iex> get_clan_membership!(456)
      ** (Ecto.NoResultsError)

  """
  def get_clan_membership!(clan_id, user_id) do
    ClanMembershipLib.get_clan_memberships()
    |> ClanMembershipLib.search(%{clan_id: clan_id, user_id: user_id})
    |> Repo.one!()
  end

  @spec get_clan_membership(Integer.t(), Integer.t()) :: ClanMembership.t() | nil
  def get_clan_membership(clan_id, user_id) do
    ClanMembershipLib.get_clan_memberships()
    |> ClanMembershipLib.search(%{clan_id: clan_id, user_id: user_id})
    |> Repo.one()
  end

  @doc """
  Creates a clan_membership.

  ## Examples

      iex> create_clan_membership(%{field: value})
      {:ok, %ClanMembership{}}

      iex> create_clan_membership(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_clan_membership(attrs) do
    %ClanMembership{}
    |> ClanMembership.changeset(attrs)
    |> Repo.insert()
  end

  def create_clan_membership(clan_id, user_id) do
    %ClanMembership{}
    |> ClanMembership.changeset(%{
      clan_id: clan_id,
      user_id: user_id
    })
    |> Repo.insert()
  end

  @doc """
  Updates a ClanMembership.

  ## Examples

      iex> update_clan_membership(clan_membership, %{field: new_value})
      {:ok, %Ruleset{}}

      iex> update_clan_membership(clan_membership, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_clan_membership(%ClanMembership{} = clan_membership, attrs) do
    clan_membership
    |> ClanMembership.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ClanMembership.

  ## Examples

      iex> delete_clan_membership(clan_membership)
      {:ok, %ClanMembership{}}

      iex> delete_clan_membership(clan_membership)
      {:error, %Ecto.Changeset{}}

  """
  def delete_clan_membership(%ClanMembership{} = clan_membership) do
    Repo.delete(clan_membership)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking clan_membership changes.

  ## Examples

      iex> change_clan_membership(clan_membership)
      %Ecto.Changeset{source: %ClanMembership{}}

  """
  def change_clan_membership(%ClanMembership{} = clan_membership) do
    ClanMembership.changeset(clan_membership, %{})
  end
end
