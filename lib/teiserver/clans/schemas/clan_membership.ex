defmodule Teiserver.Clans.ClanMembership do
  use TeiserverWeb, :schema

  @primary_key false
  typed_schema "teiserver_clan_memberships" do
    field :role, :string

    belongs_to :user, Teiserver.Account.User, primary_key: true
    belongs_to :clan, Teiserver.Clans.Clan, primary_key: true

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
