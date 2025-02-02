defmodule Teiserver.Autohost do
  alias Teiserver.Autohost.Registry
  alias Teiserver.Bot.Bot
  alias Teiserver.BotQueries

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

  @type start_response :: Teiserver.Autohost.TachyonHandler.start_response()

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

  @spec start_matchmaking(Bot.id(), start_script()) ::
          {:ok, start_response()} | {:error, term()}
  defdelegate start_matchmaking(bot_id, start_script),
    to: Teiserver.Autohost.TachyonHandler
end
