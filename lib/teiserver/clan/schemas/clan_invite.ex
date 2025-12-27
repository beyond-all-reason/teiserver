defmodule Teiserver.Clan.ClanInvite do
  use TeiserverWeb, :schema

  @primary_key false
  schema "teiserver_clan_invites" do
    field :response, :string

    belongs_to :user, Teiserver.Account.User, primary_key: true
    belongs_to :clan, Teiserver.Clan.ClanSchema, primary_key: true

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:clan_id, :user_id, :response])
    |> validate_required([:clan_id, :user_id])
    |> unique_constraint([:clan_id, :user_id])
  end
end
