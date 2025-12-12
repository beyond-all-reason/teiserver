defmodule Teiserver.Game.AchievementType do
  use TeiserverWeb, :schema

  schema "teiserver_achievement_types" do
    field :name, :string
    field :grouping, :string

    field :icon, :string
    field :colour, :string

    field :description, :string
    field :rarity, :integer, default: 0
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(name grouping icon description)a)

    struct
    |> cast(params, ~w(name grouping icon colour description rarity)a)
    |> validate_required(~w(name grouping icon colour description rarity)a)
  end

  @spec authorize(atom(), Plug.Conn.t(), map()) :: bool()
  def authorize(_action, conn, _params), do: allow?(conn, "Admin")
end
