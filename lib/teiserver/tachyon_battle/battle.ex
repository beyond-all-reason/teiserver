defmodule Teiserver.TachyonBattle.Battle do
  require Logger

  alias Teiserver.TachyonBattle.Types, as: T
  alias Teiserver.TachyonBattle.Registry

  # For now, don't do any restart. The genserver is only used to hold some
  # transient state. Later, we can attempt to reconstruct some state after
  # a restart based on the message we get.
  use GenServer, restart: :temporary

  @type state :: %{
          id: T.id(),
          autohost_id: Teiserver.Autohost.id()
        }

  def start_link({battle_id, _autohost_id} = arg) do
    GenServer.start_link(__MODULE__, arg, name: via_tuple(battle_id))
  end

  @impl true
  def init({battle_id, autohost_id}) do
    Logger.metadata(battle_id: battle_id)

    state = %{
      id: battle_id,
      autohost_id: autohost_id
    }

    Logger.info("init battle for autohost #{autohost_id}")

    {:ok, state}
  end

  defp via_tuple(battle_id) do
    Registry.via_tuple(battle_id)
  end
end
