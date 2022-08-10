defmodule Teiserver.Account.Rating do
  use CentralWeb, :schema

  @primary_key false
  schema "teiserver_account_ratings" do
    belongs_to :user, Central.Account.User, primary_key: true
    belongs_to :rating_type, Teiserver.Game.RatingType, primary_key: true

    field :rating_value, :float
    field :skill, :float
    field :uncertainty, :float

    field :leaderboard_rating, :float

    field :last_updated, :utc_datetime
  end

  @doc false
  def changeset(stats, attrs \\ %{}) do
    stats
      |> cast(attrs, ~w(user_id rating_type_id rating_value skill uncertainty last_updated leaderboard_rating)a)
      |> validate_required(~w(user_id rating_type_id rating_value skill uncertainty last_updated leaderboard_rating)a)
  end
end
