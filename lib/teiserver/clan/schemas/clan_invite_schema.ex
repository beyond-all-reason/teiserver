defmodule Teiserver.Clan.ClanInviteSchema do
  use TeiserverWeb, :schema
  alias Teiserver.Account.User
  alias Teiserver.Clan.ClanSchema

  @moduledoc """
  Database schema for clan invites

  DB table:
  teiserver_clan_invites
  user_id(int8),clan_id(int8)inserted_at(timestamp),updated_at(timestamp)

  """

  @primary_key false
  typed_schema "teiserver_clan_invites" do
    belongs_to :user, User, foreign_key: :user_id, primary_key: true
    belongs_to :clan, ClanSchema, foreign_key: :clan_id, primary_key: true
    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:clan_id, :user_id])
    |> validate_required([:clan_id, :user_id])
    |> unique_constraint([:clan_id, :user_id])
  end
end
