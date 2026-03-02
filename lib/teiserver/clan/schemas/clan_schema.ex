defmodule Teiserver.Clan.ClanSchema do
  use TeiserverWeb, :schema
  alias Teiserver.Clan.ClanMembershipsSchema
  alias Teiserver.Clan.ClanInviteSchema
  # alias Teiserver.Account.User

  @moduledoc """
  Database schema for clans

  clanBaseData
  - clanId: string
  - clanUpdateableData
    - name: string (max 30)
    - tag: string (min 3 max 6)
    - description: string (max 500)
  - Array of clanMember:
    - userId: string
    - role: clanRole [member, coLeader, leader]
    - joinedAt: unixTime

  DB table:
  teiserver_clans
  id(int8),name(varchar),tag(varchar),icon(varchar),description(text),inserted_at(timestamp),updated_at(timestamp)
  """

  @typedoc """
  The Clan schema type
  """
  @type t :: %__MODULE__{
          name: String.t(),
          tag: String.t(),
          description: String.t()
        }

  schema "teiserver_clans" do
    field :name, :string
    field :tag, :string
    field :description, :string

    has_many :members, ClanMembershipsSchema, foreign_key: :clan_id

    # many_to_many :memberships, User,
    #  join_through: "teiserver_clan_memberships",
    #  join_keys: [clan_id: :id, user_id: :id]

    has_many :invites, ClanInviteSchema, foreign_key: :clan_id

    # many_to_many :invitees, User,
    #  join_through: "teiserver_clan_invites",
    #   join_keys: [clan_id: :id, user_id: :id]

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(name tag description)a)

    struct
    |> cast(params, ~w(name tag description)a)
    |> validate_required(~w(name tag description)a)
  end

  # RALA ???
  def authorize(_, conn, _), do: allow?(conn, "clan")
end
