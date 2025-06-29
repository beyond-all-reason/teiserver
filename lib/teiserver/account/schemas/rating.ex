defmodule Teiserver.Account.Rating do
  use TeiserverWeb, :schema

  @type t() :: %__MODULE__{
          rating_type: Teiserver.Game.RatingType.t(),
          season: integer(),
          rating_value: number(),
          skill: number(),
          uncertainty: number(),
          leaderboard_rating: number(),
          num_matches: non_neg_integer(),
          num_wins: non_neg_integer()
        }

  @primary_key false
  schema "teiserver_account_ratings" do
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
  end

  @doc false
  def changeset(stats, attrs \\ %{}) do
    stats
    |> cast(
      attrs,
      ~w(user_id rating_type_id rating_value skill uncertainty last_updated leaderboard_rating num_matches num_wins season)a
    )
    # fields below are required; num_matches is not required
    |> validate_required(
      ~w(user_id rating_type_id rating_value skill uncertainty last_updated leaderboard_rating season)a
    )
  end
end
