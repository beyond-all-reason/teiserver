defmodule Teiserver.Tournament.Team do
  use CentralWeb, :schema

  schema "teiserver_tournament_teams" do
    field :name, :string

    field :icon, :string
    field :colour, :string

    # Clan is optional, if clan based then only clan members can be added
    belongs_to :clan, Teiserver.Clans.Clan

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(name)a)

    struct
    |> cast(params, ~w(name icon colour clan_id)a)
    |> validate_required(~w(name icon colour)a)
  end

  def authorize(_, conn, _), do: allow?(conn, "clan")
end
