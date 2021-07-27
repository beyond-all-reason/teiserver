defmodule Teiserver.Tournament.Tournament do
  use CentralWeb, :schema

  schema "teiserver_tournament_tournaments" do
    field :string

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:team_id, :user_id])
    |> validate_required([:team_id, :user_id])
    |> unique_constraint([:team_id, :user_id])
  end
end
