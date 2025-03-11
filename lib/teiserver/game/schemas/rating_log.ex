defmodule Teiserver.Game.RatingLog do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "teiserver_game_rating_logs" do
    belongs_to :user, Teiserver.Account.User
    belongs_to :rating_type, Teiserver.Game.RatingType
    belongs_to :match, Teiserver.Battle.Match
    field :party_id, :string, default: nil

    field :value, :map
    field :inserted_at, :utc_datetime

    has_one :match_membership,
      through: [:match, :members]

    field :season, :integer
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(user_id rating_type_id match_id value inserted_at party_id season)a)
    |> validate_required(~w(user_id rating_type_id value inserted_at season)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), map()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "Admin")
end
