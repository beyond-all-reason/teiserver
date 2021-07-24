defmodule Teiserver.Clans.Clan do
  use CentralWeb, :schema

  schema "teiserver_clans" do
    field :name, :string
    field :tag, :string

    field :icon, :string
    field :colour1, :string
    field :colour2, :string
    field :text_colour, :string

    field :description, :string

    field :rating, :map, default: %{}
    field :homepage, :map, default: %{}

    has_many :memberships, Teiserver.Clans.ClanMembership, foreign_key: :clan_id
    has_many :invites, Teiserver.Clans.ClanInvite, foreign_key: :clan_id

    many_to_many :members, Central.Account.User,
      join_through: "teiserver_clan_memberships",
      join_keys: [clan_id: :id, user_id: :id]

    many_to_many :invitees, Central.Account.User,
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
      |> trim_strings([:name, :tag, :icon, :colour1, :colour2, :text_colour, :description])
      |> remove_characters([:tag], [~r/[\[\]]/])

    struct
    |> cast(params, [:name, :tag, :icon, :colour1, :colour2, :text_colour, :description, :rating, :homepage])
    |> validate_required([:name, :tag, :icon, :colour1, :colour2, :text_colour, :description, :rating, :homepage])
  end

  def authorize(_, conn, _), do: allow?(conn, "clan")
end
