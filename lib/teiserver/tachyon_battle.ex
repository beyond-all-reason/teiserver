defmodule Teiserver.TachyonBattle do
  @moduledoc """
  To track ongoing battle. A battle should be linked with a running instance
  of the engine on an autohost.

  Ideally this should only be called Battle, but this clashes with the existing
  battle system tied to spring protocol and spads. This version, as the name
  suggest, is meant to be used with tachyon and autohosts.
  """

  require Logger
  alias Teiserver.Bot
  alias Teiserver.TachyonBattle.Types, as: T
  alias Teiserver.{TachyonBattle, Autohost}

  @type id :: T.id()
  @type start_script :: T.start_script()

  @spec start_battle(Teiserver.Autohost.id()) :: {:ok, T.id()} | {:error, term()}
  def start_battle(autohost_id) do
    battle_id = gen_id()
    # TODO: handle potential errors, like "already registered"
    case TachyonBattle.Supervisor.start_battle(battle_id, autohost_id) do
      {:ok, _pid} ->
        {:ok, battle_id}

      {:ok, _pid, _info} ->
        {:ok, battle_id}

      err ->
        Logger.warning("Cannot start battle: #{inspect(err)}")
        {:error, "cannot start battle: #{inspect(err)}"}
    end
  end

  @spec lookup(T.id()) :: pid() | nil
  defdelegate lookup(battle_id), to: TachyonBattle.Registry

  @doc """
  Start a battle process and connects it to the given autohost
  """
  @spec start_battle(Bot.id(), T.start_script()) ::
          {:ok, Autohost.start_response()} | {:error, term()}
  def start_battle(autohost_id, start_script) do
    with {:ok, battle_id} <- start_battle(autohost_id) do
      start_script = Map.put(start_script, :battleId, battle_id)
      Logger.info("Starting battle with id #{battle_id} on autohost #{autohost_id}")

      case Teiserver.Autohost.start_battle(autohost_id, start_script) do
        {:ok, data} -> {:ok, battle_id, data}
        x -> x
      end
    end
  end

  # keep this function private to dissuade caller to misuse the API.
  # Generating a battle id is meaningless unless the corresponding
  # Battle genserver is also started and connected to an autohost
  @spec gen_id() :: T.id()
  defp gen_id(), do: UUID.uuid4()
end
