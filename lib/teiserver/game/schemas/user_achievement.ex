defmodule Teiserver.Game.UserAchievement do
  use TeiserverWeb, :schema

  @primary_key false
  typed_schema "teiserver_user_achievements" do
    belongs_to :user, Teiserver.Account.User, primary_key: true
    belongs_to :achievement_type, Teiserver.Game.AchievementType, primary_key: true

    field :achieved, :boolean, default: false
    field :progress, :integer

    field :inserted_at, :utc_datetime
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(user_id achievement_type_id achieved progress inserted_at)a)
    |> validate_required(~w(user_id achievement_type_id achieved inserted_at)a)
  end

  @spec authorize(atom(), Plug.Conn.t(), map()) :: bool()
  def authorize(_, conn, _), do: allow?(conn, "account")
end
