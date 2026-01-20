defmodule Teiserver.Autohost do
  alias Teiserver.Autohost.Session
  alias Teiserver.Autohost.SessionRegistry
  alias Teiserver.Autohost.TachyonHandler
  alias Teiserver.Bot.Bot
  alias Teiserver.BotQueries
  alias Teiserver.TachyonBattle
  alias Teiserver.Data.Types, as: T

  @type id :: Teiserver.Bot.Bot.id()
  @type reg_value :: SessionRegistry.reg_value()

  @type start_script :: %{
          required(:engine_version) => String.t(),
          required(:game_name) => String.t(),
          required(:map_name) => String.t(),
          required(:start_pos_type) => :fixed | :random | :ingame | :beforegame,
          required(:ally_teams) => [ally_team(), ...],
          optional(:spectators) => [player()],
          optional(:bots) => [bot()]
        }

  @type ally_team :: %{
          teams: [team(), ...]
        }

  @type team :: %{
          players: [player()]
        }

  @type player :: %{
          user_id: T.userid(),
          name: String.t(),
          password: String.t()
        }

  @type bot :: %{
          host_user_id: T.userid(),
          name: String.t(),
          ai_short_name: String.t(),
          ai_version: String.t(),
          ai_options: %{String.t() => term()}
        }

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
  @spec lookup_autohost(Bot.id()) :: {pid(), reg_value()} | nil
  def lookup_autohost(bot_id) do
    SessionRegistry.lookup(bot_id)
  end

  @spec lookup_autohost(Bot.id()) :: {pid(), reg_value()} | nil
  def lookup_autohost_connection(bot_id) do
    Teiserver.Autohost.Registry.lookup(bot_id)
  end

  @spec list() :: [reg_value()]
  defdelegate list(), to: SessionRegistry

  @doc """
  Given some search params (none for now), find a autohost that is connected,
  has capacity, and matches the search params.
  """
  @spec find_autohost(term()) :: id() | nil
  def find_autohost(_params \\ %{}) do
    autohost_val =
      SessionRegistry.list()
      |> Enum.find(fn %{max_battles: m, current_battles: c} -> m > c end)

    if autohost_val == nil, do: nil, else: autohost_val[:id]
  end

  @spec start_battle(Bot.id(), Teiserver.TachyonBattle.id(), start_script()) ::
          {:ok, start_response()} | {:error, term()}
  defdelegate start_battle(bot_id, battle_id, start_script),
    to: Session

  @spec send_message(pid(), %{battle_id: TachyonBattle.id(), message: String.t()}) ::
          :ok | {:error, reason :: term()}
  defdelegate send_message(autohost, payload),
    to: Teiserver.Autohost.TachyonHandler

  @spec kill_battle(pid(), TachyonBattle.id()) :: :ok
  defdelegate kill_battle(autohost, battle_id),
    to: Teiserver.Autohost.TachyonHandler
end
