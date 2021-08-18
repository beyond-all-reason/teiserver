defmodule Teiserver.Battle.Match do
  use CentralWeb, :schema

  schema "teiserver_battle_matches" do
    field :uuid, :string
    field :map, :string
    field :data, :map # The end of match data to be provided by clients
    field :tags, :map

    field :team_count, :integer
    field :team_size, :integer
    field :passworded, :boolean
    field :game_type, :string # pve, 1v1, team, team_ffa, ffa

    belongs_to :founder, Central.Account.User
    field :bots, :map

    # TODO: Clan support?
    # TODO: Tourney support?

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
    |> cast(params, ~w(uuid map data tags team_count team_size passworded game_type founder_id bots started finished)a)
    |> validate_required(~w(uuid map tags team_count team_size passworded game_type founder_id bots started)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "teiserver")
end
