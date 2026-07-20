defmodule Teiserver.Player.Types.Data do
  @moduledoc """
  internal data for a player's session
  """

  alias Teiserver.Account.User
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.Player.Types, as: PT
  alias Teiserver.TachyonLobby

  @enforce_keys [:user, :matchmaking, :messaging_state, :party]
  defstruct [
    :user,
    :matchmaking,
    :messaging_state,
    :party,
    monitors: MC.new(),
    conn_pid: nil,
    user_subscriptions: MapSet.new(),
    battle: nil,
    lobby: nil,
    lobby_list_subscription: nil
  ]

  @type matchmaking_state ::
          :no_matchmaking
          | {:searching, PT.MmSearchingState.t()}
          | {:pairing, PT.MmPairingState.t()}

  @type t :: %__MODULE__{
          user: T.user(),
          monitors: MC.t(),
          conn_pid: pid() | nil,
          matchmaking: matchmaking_state(),
          messaging_state: PT.MessagingState.t(),
          party: PT.PartyState.t(),
          user_subscriptions: MapSet.t(User.id()),
          battle: PT.BattleState.t() | nil,
          lobby: nil | %{id: TachyonLobby.id()},
          lobby_list_subscription:
            nil
            | %{
                timer_ref: :timer.tref(),
                lobbies: %{TachyonLobby.id() => %{counter: integer(), changes: map()}}
              }
        }
end
