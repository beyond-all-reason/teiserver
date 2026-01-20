defmodule Teiserver.Account.Rating do
  use TeiserverWeb, :schema

  @primary_key false
  typed_schema "teiserver_account_ratings" do
    belongs_to :user, Teiserver.Account.User, primary_key: true
    belongs_to :rating_type, Teiserver.Game.RatingType, primary_key: true

    field :season, :integer, primary_key: true

    field :rating_value, :float
    field :skill, :float
    field :uncertainty, :float

    field :leaderboard_rating, :float

    field :last_updated, :utc_datetime
    field :num_matches, :integer
    field :num_wins, :integer
    field :total_matches, :integer
    field :total_wins, :integer
  end

  @doc false
  def changeset(stats, attrs \\ %{}) do
    stats
    |> cast(
      attrs,
      ~w(user_id rating_type_id rating_value skill uncertainty last_updated leaderboard_rating num_matches num_wins season total_matches total_wins)a
    )
    # fields below are required; num_matches is not required
    |> validate_required(
      ~w(user_id rating_type_id rating_value skill uncertainty last_updated leaderboard_rating season)a
    )
  end
end
