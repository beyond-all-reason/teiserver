defmodule Teiserver.Matchmaking.QueueServer do
  @moduledoc """
  Very similar to Teiserver.Game.QueueWaitServer

  This process manages a given queue and attempt to match the members to play
  matches. Once player are matched, they are excluded from this queue and passed
  to a QueueRoomServer
  It also has some associated state for telemetry.
  """

  use GenServer

  @typedoc """
  member of a queue. Holds of the information required to match members together.
  A member can be a party of players. Parties must not be broken.
  """
  @type member :: %{
          player_ids: [T.userid()],
          # maybe also add (aggregated) chevron if that's taking into account
          # map keyed by the rating type to {skill, uncertainty}
          # For example %{"duel" => {12, 3.2}}
          rating: %{String.t() => {integer(), integer()}},
          # aggregate of player to avoid for this member
          avoid: [T.userid()],
          joined_at: DateTime.t(),
          search_distance: non_neg_integer(),
          # how many ticks remaining before increasing the search distance
          increase_distance_after: non_neg_integer()
        }

  @type id :: String.t()

  @typedoc """
  Internal settings for the queue so it's easier to control the frequency of
  ticks and whatnot
  """
  @type settings :: %{
          tick_interval_ms: pos_integer(),
          max_distance: pos_integer()
        }
  @type state :: %{
          id: id(),
          name: String.t(),
          team_size: pos_integer(),
          team_count: pos_integer(),
          settings: settings(),
          members: [member()]

          # TODO: add some bits for telemetry (see QueueWaitServer) like avg
          # wait time and join count
        }

  @spec default_settings() :: settings()
  def default_settings() do
    %{tick_interval_ms: 5_000, max_distance: 15}
  end

  @doc """
  Create a state for the GenServer, filling missing attributes with defaults
  """
  @spec init_state(%{
          required(:id) => id(),
          required(:name) => String.t(),
          required(:team_size) => pos_integer(),
          required(:team_count) => pos_integer(),
          optional(:settings) => settings(),
          optional(:members) => [member()]
        }) :: state()
  def init_state(attrs) do
    %{
      id: attrs.id,
      name: attrs.name,
      team_size: attrs.team_size,
      team_count: attrs.team_count,
      settings: Map.merge(default_settings(), Map.get(attrs, :settings, %{})),
      members: Map.get(attrs, :members, [])
    }
  end

  def via_tuple(queue_id) do
    Teiserver.Matchmaking.QueueRegistry.via_tuple(queue_id)
  end

  @spec start_link(state()) :: GenServer.on_start()
  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state, name: via_tuple(initial_state.id))
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

end
