defmodule Teiserver.Clan do
  @moduledoc """
  This module handles clans: their creation, updating, deletion and searching.
  It also manages clan memberships and invites.
  """

  import Ecto.Query, warn: false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo

  alias Teiserver.Clan.ClanSchema
  alias Teiserver.Clan.ClanInviteSchema
  alias Teiserver.Clan.ClanMembershipsSchema

  alias Teiserver.Clan.ClanLib
  alias Teiserver.Clan.ClanInviteLib
  alias Teiserver.Clan.ClanMemberLib

  @spec clan_query(nil | maybe_improper_list() | map()) :: Ecto.Query.t()
  defp clan_query(args) do
    clan_query(nil, args)
  end

  @spec clan_query(any(), nil | maybe_improper_list() | map()) :: Ecto.Query.t()
  defp clan_query(id, args) do
    ClanLib.query_clans()
    |> ClanLib.search(%{id: id})
    |> ClanLib.search(args[:search])
    |> ClanLib.preload(args[:preload])
    |> ClanLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of clans. (Default limit 50.)

  ## Examples
    iex> list_clans()
    iex> list_clans(limit: 10)
    iex> list_clans(order_by: "Name (A-Z)")
  """
  @spec list_clans(nil | maybe_improper_list() | map()) :: any()
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
      %ClanSchema{}

      iex> get_clan!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_clan!(any()) :: any()
  def get_clan!(id) when not is_list(id) do
    clan_query(id, [])
    |> Repo.one!()
  end

  @spec get_clan!(nil | maybe_improper_list() | map()) :: any()
  def get_clan!(args) do
    clan_query(nil, args)
    |> Repo.one!()
  end

  @spec get_clan!(any(), nil | maybe_improper_list() | map()) :: any()
  def get_clan!(id, args) do
    clan_query(id, args)
    |> Repo.one!()
  end

  def get_clan(nil), do: nil
  def get_clan(id), do: get_clan(id, [])
  def get_clan(nil, _), do: nil

  def get_clan(id, args) when not is_list(id) do
    clan_query(id, args)
    |> Repo.one()
  end

  @doc """
  Creates a new clan with the given parameters.

  ## Parameters
  - `params`: A map containing the attributes required to create a clan.

  ## Returns
  - `{:ok, clan}`: If the clan is successfully created, returns a tuple with `:ok` and the created clan.
  - `{:error, changeset}`: If there is an error during creation, returns a tuple with `:error` and the changeset containing validation errors.

  ## Examples

      iex> create_clan(tag: "WR1", name: "Warriors", description: "A clan of warriors")
      {:ok, %Clan{}}

      iex> create_clan(name: nil)
      {:error, %Ecto.Changeset{}}
  """
  @spec create_clan(map()) :: {:ok, ClanSchema.t()} | {:error, Ecto.Changeset.t()}
  def create_clan(attrs \\ %{}) do
    %ClanSchema{}
    |> ClanSchema.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a clan with the given attributes.

  ## Parameters

    - `clan`: The clan to be updated.
    - `attrs`: A map of attributes to update the clan with.

  ## Returns

    - `{:ok, %Clan{}}` if the update is successful.
    - `{:error, %Ecto.Changeset{}}` if the update fails due to validation errors.

  ## Examples

      iex> update_clan(clan, %{field: new_value})
      {:ok, %Clan{}}

      iex> update_clan(clan, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_clan(%ClanSchema{} = clan, attrs) do
    clan
    |> ClanSchema.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Clan from the database.

  ## Parameters

    - clan: The `%Clan{}` struct representing the clan to be deleted.

  ## Returns

    - `{:ok, %Clan{}}` if the clan was successfully deleted.
    - `{:error, %Ecto.Changeset{}}` if there was an error during deletion.

  ## Examples

      iex> delete_clan(clan)
      {:ok, %Clan{}}

      iex> delete_clan(clan)
      {:error, %Ecto.Changeset{}}
  """
  def delete_clan(%ClanSchema{} = clan) do
    Repo.delete(clan)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking clan changes.

  ## Examples

      iex> change_clan(clan)
      %Ecto.Changeset{source: %Clan{}}

  """
  def change_clan(%ClanSchema{} = clan) do
    ClanSchema.changeset(clan, %{})
  end

  @doc """
  Returns the list of clan_invites.

  ## Examples

      iex> list_clan_invites_by_clan(1, preload: [:clan, :user])
      {user_id: 2, ....}

  """
  def list_clan_invites_by_clan(clan_id, args \\ []) do
    ClanInviteLib.get_clan_invites()
    |> ClanInviteLib.search(clan_id: clan_id)
    |> ClanInviteLib.search(args[:search])
    |> ClanInviteLib.preload(args[:preload])
    |> QueryHelpers.query_select(args[:select])
    |> Repo.all()
  end

  def list_clan_invites_by_user(user_id, args \\ []) do
    ClanInviteLib.get_clan_invites()
    |> ClanInviteLib.search(user_id: user_id)
    |> ClanInviteLib.search(args[:search])
    |> ClanInviteLib.preload(args[:preload])
    |> QueryHelpers.query_select(args[:select])
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

      iex> create_clan_invite(1,2)
      {:ok, %ClanInvite{}}

      iex> create_clan_invite(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_clan_invite(attrs) do
    %ClanInviteSchema{}
    |> ClanInviteSchema.changeset(attrs)
    |> Repo.insert()
  end

  def create_clan_invite(clan_id, user_id) do
    %ClanInviteSchema{}
    |> ClanInviteSchema.changeset(%{
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
  def update_clan_invite(%ClanInviteSchema{} = clan_invite, attrs) do
    clan_invite
    |> ClanInviteSchema.changeset(attrs)
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
  def delete_clan_invite(%ClanInviteSchema{} = clan_invite) do
    Repo.delete(clan_invite)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking clan_invite changes.

  ## Examples

      iex> change_clan_invite(clan_invite)
      %Ecto.Changeset{source: %ClanInvite{}}

  """
  def change_clan_invite(%ClanInviteSchema{} = clan_invite) do
    ClanInviteSchema.changeset(clan_invite, %{})
  end

  @doc """
  Returns the list of clan_memberships.

  ## Examples

      iex> list_clan_memberships_by_clan(1)
      iex> list_clan_memberships_by_clan(1,preload: [:clan])

      iex> list_clan_memberships_by_user(1)
      iex> list_clan_memberships_by_user(1,preload: [:clan])

  """
  def list_clan_memberships_by_clan(clan_id, args \\ []) do
    ClanMemberLib.get_clan_member()
    |> ClanMemberLib.search(clan_id: clan_id)
    |> ClanMemberLib.search(args[:search])
    |> ClanMemberLib.preload(args[:preload])
    |> QueryHelpers.query_select(args[:select])
    |> Repo.all()
  end

  def list_clan_memberships_by_user(user_id, args \\ []) do
    ClanMemberLib.get_clan_member()
    |> ClanMemberLib.search(user_id: user_id)
    |> ClanMemberLib.search(args[:search])
    |> ClanMemberLib.preload(args[:preload])
    |> QueryHelpers.query_select(args[:select])
    |> Repo.all()
  end

  @doc """
  Gets a single clan_membership.

  Raises `Ecto.NoResultsError` if the ClanMembership does not exist.

  ## Examples

      iex> get_clan_membership!(123)
      %ClanMemberLib{}

      iex> get_clan_membership!(456)
      ** (Ecto.NoResultsError)

  """
  def get_clan_membership!(clan_id, user_id) do
    ClanMemberLib.get_clan_member()
    |> ClanMemberLib.search(%{clan_id: clan_id, user_id: user_id})
    |> Repo.one!()
  end

  @spec get_clan_membership(any(), any()) :: ClanMembershipsSchema.t() | nil
  def get_clan_membership(clan_id, user_id) do
    ClanMemberLib.get_clan_member()
    |> ClanMemberLib.search(%{clan_id: clan_id, user_id: user_id})
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
    %ClanMembershipsSchema{}
    |> ClanMembershipsSchema.changeset(attrs)
    |> Repo.insert()
  end

  def create_clan_membership(clan_id, user_id) do
    %ClanMembershipsSchema{}
    |> ClanMembershipsSchema.changeset(%{
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
  def update_clan_membership(%ClanMembershipsSchema{} = clan_membership, attrs) do
    clan_membership
    |> ClanMembershipsSchema.changeset(attrs)
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
  def delete_clan_membership(%ClanMembershipsSchema{} = clan_membership) do
    Repo.delete(clan_membership)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking clan_membership changes.

  ## Examples

      iex> change_clan_membership(clan_membership)
      %Ecto.Changeset{source: %ClanMembership{}}

  """
  def change_clan_membership(%ClanMembershipsSchema{} = clan_membership) do
    ClanMembershipsSchema.changeset(clan_membership, %{})
  end

  def count_clan_members(clan_id) do
    ClanMemberLib.get_clan_member()
    |> ClanMemberLib.search(clan_id: clan_id)
    |> Repo.aggregate(:count, :id)
  end

  def list_clan_members(clan_id) do
    ClanMemberLib.get_clan_member()
    |> ClanMemberLib.search(clan_id: clan_id)
    |> Repo.all()
  end
end
