defmodule Teiserver.Autohost do
  alias Teiserver.Autohost.Registry
  alias Teiserver.Autohost.TachyonHandler
  alias Teiserver.Bot.Bot
  alias Teiserver.BotQueries
  alias Teiserver.TachyonBattle

  @type id :: Teiserver.Bot.Bot.id()
  @type reg_value :: Registry.reg_value()

  @type start_script :: %{
          battleId: Teiserver.TachyonBattle.id(),
          engineVersion: String.t(),
          gameName: String.t(),
          mapName: String.t(),
          startPosType: :fixed | :random | :ingame | :beforegame,
          allyTeams: [ally_team(), ...]
        }

  @type ally_team :: %{
          teams: [team(), ...]
        }

  @type team :: %{
          players: [player()]
        }

  @type player :: %{
          userId: String.t(),
          name: String.t(),
          password: String.t()
        }

  @type start_response :: TachyonHandler.start_response()

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
  Returns the pid of the autohost registered with a given id
  """
  @spec lookup_autohost(Bot.id()) :: {pid(), reg_value()} | nil
  def lookup_autohost(bot_id) do
    Teiserver.Autohost.Registry.lookup(bot_id)
  end

  @spec list() :: [reg_value()]
  defdelegate list(), to: Registry

  @doc """
  Given some search params (none for now), find a autohost that is connected,
  has capacity, and matches the search params.
  """
  @spec find_autohost(term()) :: id() | nil
  def find_autohost(_params \\ %{}) do
    autohost_val =
      Registry.list()
      |> Enum.find(fn %{max_battles: m, current_battles: c} -> m > c end)

    if autohost_val == nil, do: nil, else: autohost_val[:id]
  end

  @spec start_battle(Bot.id(), start_script()) ::
          {:ok, start_response()} | {:error, term()}
  defdelegate start_battle(bot_id, start_script),
    to: Teiserver.Autohost.TachyonHandler

  @spec send_message(pid(), %{battle_id: TachyonBattle.id(), message: String.t()}) ::
          :ok | {:error, reason :: term()}
  defdelegate send_message(autohost, payload),
    to: Teiserver.Autohost.TachyonHandler

  @spec kill_battle(pid(), TachyonBattle.id()) :: :ok
  defdelegate kill_battle(autohost, battle_id),
    to: Teiserver.Autohost.TachyonHandler
end
