defmodule Teiserver.Battle.Match do
  use CentralWeb, :schema

  schema "teiserver_battle_matches" do
    field :server_uuid, :string
    field :uuid, :string
    field :map, :string
    field :data, :map, default: %{} # The end of match data to be provided by clients
    field :tags, :map

    field :winning_team, :integer
    field :team_count, :integer
    field :team_size, :integer
    field :passworded, :boolean
    field :processed, :boolean, default: false
    field :game_type, :string # Scavengers, Raptors, Bots, Duel, Team, FFA, Team FFA

    belongs_to :founder, Central.Account.User
    field :bots, :map

    # TODO: Clan support?
    # TODO: Tourney support?

    belongs_to :queue, Teiserver.Game.Queue

    field :started, :utc_datetime
    field :finished, :utc_datetime
    field :game_duration, :integer

    has_many :members, Teiserver.Battle.MatchMembership
    has_many :ratings, Teiserver.Game.RatingLog

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
      |> cast(params, ~w(server_uuid uuid map data tags team_count team_size passworded game_type founder_id bots started winning_team finished processed queue_id game_duration)a)
      |> validate_required(~w(server_uuid uuid map tags team_count team_size passworded game_type founder_id bots started)a)
  end

  @spec initial_changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def initial_changeset(struct, params \\ %{}) do
    struct
      |> cast(params, ~w(server_uuid uuid map data tags team_count team_size passworded game_type founder_id bots started winning_team finished processed queue_id game_duration)a)
      |> validate_required(~w(founder_id)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "teiserver")
end
