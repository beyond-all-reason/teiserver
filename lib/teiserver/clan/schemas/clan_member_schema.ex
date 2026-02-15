defmodule Teiserver.Clan.ClanMemberSchema do
  use TeiserverWeb, :schema
  alias Teiserver.Account.User
  alias Teiserver.Clan.ClanSchema

  @moduledoc """
  Database schema for clan member

  clanMember:
  --- userId: string
  --- role: clanRole [member, coLeader, leader]
  --- joinedAt: unixTime

  DB table:
  teiserver_clan_memberships
  user_id(int8),clan_id(int8),role(varchar),inserted_at(timestamp),updated_at(timestamp)

  """

  @primary_key false
  typed_schema "teiserver_clan_memberships" do
    field :role, :string
    belongs_to :user, User, primary_key: true
    belongs_to :clan, ClanSchema, primary_key: true
    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:clan_id, :user_id, :role])
    |> validate_required([:clan_id, :user_id])
    |> unique_constraint([:clan_id, :user_id])
  end
end
