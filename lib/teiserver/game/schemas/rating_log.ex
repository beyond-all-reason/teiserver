defmodule Barserver.Game.RatingLog do
  @moduledoc false
  use BarserverWeb, :schema

  schema "teiserver_game_rating_logs" do
    belongs_to :user, Barserver.Account.User
    belongs_to :rating_type, Barserver.Game.RatingType
    belongs_to :match, Barserver.Battle.Match
    field :party_id, :string, default: nil

    field :value, :map
    field :inserted_at, :utc_datetime

    has_one :match_membership,
      through: [:match, :members]
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
  def authorize(_, conn, _), do: allow?(conn, "Admin")
end
