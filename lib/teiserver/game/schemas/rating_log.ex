defmodule Teiserver.Game.RatingLog do
  use CentralWeb, :schema

  schema "teiserver_game_rating_logs" do
    belongs_to :user, Central.Account.User
    belongs_to :rating_type, Teiserver.Game.RatingType
    belongs_to :match, Teiserver.Battle.Match
    field :party_id, :string, default: nil

    field :value, :map
    field :inserted_at, :utc_datetime

    has_one :match_membership, Teiserver.Battle.MatchMembership


    # has_one :match_membership, Teiserver.Battle.MatchMembership
    #   join_through: "teiserver_battle_matches",
    #   join_keys: [user_id: :user_id, match_id: :id]

    # through: match_memberships.user_id == rating_logs.user_id and match_memberships.match_id == rating_logs.match_id
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
      |> cast(params, ~w(user_id rating_type_id match_id value inserted_at party_id)a)
      |> validate_required(~w(user_id rating_type_id value inserted_at)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "teiserver.admin")
end
