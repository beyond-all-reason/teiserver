defmodule Teiserver.Battle.BattleLog do
  use CentralWeb, :schema

  schema "teiserver_battle_logs" do
    field :guid, :string
    field :data, :map

    field :team_count, :integer
    field :players, {:array, :integer}
    field :spectators, {:array, :integer}

    # TODO: Clan support?

    field :started, :utc_datetime
    field :finished, :utc_datetime

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:guid, :data, :team_count, :players, :spectators, :started, :finished])
    |> validate_required([:guid, :data, :team_count, :players, :spectators, :started, :finished])
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "teiserver")
end
