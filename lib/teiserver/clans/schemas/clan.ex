defmodule Teiserver.Clans.Clan do
  use TeiserverWeb, :schema

  typed_schema "teiserver_clans" do
    field :name, :string
    field :tag, :string

    field :colour, :string
    field :icon, :string

    field :description, :string

    field :rating, :map, default: %{}
    field :homepage, :map, default: %{}

    has_many :memberships, Teiserver.Clans.ClanMembership, foreign_key: :clan_id
    has_many :invites, Teiserver.Clans.ClanInvite, foreign_key: :clan_id

    many_to_many :members, Teiserver.Account.User,
      join_through: "teiserver_clan_memberships",
      join_keys: [clan_id: :id, user_id: :id]

    many_to_many :invitees, Teiserver.Account.User,
      join_through: "teiserver_clan_invites",
      join_keys: [clan_id: :id, user_id: :id]

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(name tag icon colour description)a)
      |> remove_characters(~w(tag)a, [~r/[\[\]]/])

    struct
    |> cast(params, ~w(name tag icon colour description rating homepage)a)
    |> validate_required(~w(name tag icon colour description rating homepage)a)
  end

  def authorize(_, conn, _), do: allow?(conn, "clan")
end
