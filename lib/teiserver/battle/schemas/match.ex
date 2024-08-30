defmodule Teiserver.Battle.Match do
  use TeiserverWeb, :schema

  schema "teiserver_battle_matches" do
    field :server_uuid, :string
    field :uuid, :string
    field :map, :string
    # The end of match data to be provided by clients
    field :data, :map, default: %{}
    field :tags, :map

    field :winning_team, :integer
    field :team_count, :integer
    field :team_size, :integer
    field :passworded, :boolean
    field :processed, :boolean, default: false
    # Scavengers, Raptors, Bots, Duel, Small Team, Large Team, FFA, Team FFA
    field :game_type, :string

    belongs_to :founder, Teiserver.Account.User
    field :bots, :map

    # TODO: Clan support?
    # TODO: Tourney support?

    belongs_to :queue, Teiserver.Game.Queue
    belongs_to :rating_type, Teiserver.Game.RatingType
    belongs_to :lobby_policy, Teiserver.Game.LobbyPolicy

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
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(
      params,
      ~w(server_uuid uuid map data tags team_count team_size passworded game_type founder_id bots started winning_team finished processed queue_id rating_type_id lobby_policy_id game_duration)a
    )
    |> validate_required(
      ~w(server_uuid uuid map tags team_count team_size passworded game_type founder_id bots started)a
    )
  end

  @spec initial_changeset(map(), map()) :: Ecto.Changeset.t()
  def initial_changeset(struct, params \\ %{}) do
    struct
    |> cast(
      params,
      ~w(server_uuid uuid map data tags team_count team_size passworded game_type founder_id bots started winning_team finished processed queue_id game_duration)a
    )
    |> validate_required(~w(founder_id)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), map()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "account")
end
