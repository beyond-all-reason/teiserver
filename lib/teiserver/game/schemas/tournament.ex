defmodule Teiserver.Game.Tournament do
  use CentralWeb, :schema

  schema "game_tournaments" do
    field :name, :string
    field :icon, :string
    field :colour, :string

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings([:name])

    struct
    |> cast(params, [:name, :icon, :colour])
    |> validate_required([:name, :icon, :colour])
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "game")
end
