defmodule Teiserver.Autohost do
  @moduledoc false
  alias Teiserver.Autohost.Session
  alias Teiserver.Autohost.SessionRegistry
  alias Teiserver.Autohost.TachyonHandler
  alias Teiserver.Autohost.Types, as: AT
  alias Teiserver.Bot.Bot
  alias Teiserver.BotQueries
  alias Teiserver.TachyonBattle

  @type id :: Teiserver.Bot.Bot.id()

  @type ally_team :: AT.StartScript.ally_team()
  @type team :: AT.StartScript.team()

  @type start_response :: Session.start_response()

  @type update_event_data :: TachyonHandler.update_event_data()
  @type update_event :: TachyonHandler.update_event()

  defdelegate create_autohost(attrs \\ %{}), to: Teiserver.Bot, as: :create_bot

  defdelegate change_autohost(autohost, attrs \\ %{}),
    to: Teiserver.Bot,
    as: :change_bot

  defdelegate update_autohost(autohost, attrs), to: Teiserver.Bot, as: :update_bot

  @spec delete(Bot.t()) :: :ok | {:error, term()}
  defdelegate delete(autohost), to: Teiserver.Bot, as: :delete

  defdelegate get_by_id(id), to: BotQueries

  @doc """
  Returns the data associated with an autohost session
  """
  @spec lookup_autohost(Bot.id()) :: {pid(), AT.Overview.t()} | nil
  def lookup_autohost(bot_id) do
    SessionRegistry.lookup(bot_id)
  end

  @spec lookup_autohost(Bot.id()) :: {pid(), AT.Overview.t()} | nil
  def lookup_autohost_connection(bot_id) do
    Teiserver.Autohost.Registry.lookup(bot_id)
  end

  @spec list() :: [AT.Overview.t()]
  defdelegate list(), to: SessionRegistry

  @doc """
  Given some search params (none for now), find a autohost that is connected,
  has capacity, and matches the search params.
  """
  @spec find_autohost(term()) :: id() | nil
  def find_autohost(_params \\ %{}) do
    autohost_val =
      SessionRegistry.list()
      |> Enum.find(fn %AT.Overview{max_battles: m, current_battles: c} -> m > c end)

    if autohost_val == nil, do: nil, else: autohost_val.id
  end

  @spec start_battle(Bot.id(), TachyonBattle.id(), pid(), AT.StartScript.t()) ::
          {:ok, autohost_pid :: pid(), start_response()} | {:error, term()}
  defdelegate start_battle(bot_id, battle_id, battle_pid, start_script),
    to: Session

  @spec send_message(Bot.id(), %{battle_id: TachyonBattle.id(), message: String.t()}) ::
          :ok | {:error, reason :: term()}
  defdelegate send_message(autohost, payload), to: Teiserver.Autohost.Session

  @spec kill_battle(pid(), TachyonBattle.id()) :: :ok
  defdelegate kill_battle(autohost, battle_id),
    to: Teiserver.Autohost.Session

  @spec add_player(pid(), TachyonBattle.Types.add_player_data()) :: :ok | {:error, term()}
  defdelegate add_player(session_pid, add_data), to: Session

  @spec ack_update_event(pid(), TachyonBattle.id(), DateTime.t()) :: :ok
  defdelegate ack_update_event(session_pid, battle_id, timestamp), to: Teiserver.Autohost.Session
end
