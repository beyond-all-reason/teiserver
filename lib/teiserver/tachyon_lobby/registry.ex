defmodule Teiserver.TachyonLobby.Registry do
  alias Teiserver.TachyonLobby.Lobby

  use Horde.Registry

  def start_link(_) do
    Horde.Registry.start_link(__MODULE__, [keys: :unique, strategy: :one_for_one, members: :auto],
      name: __MODULE__
    )
  end

  @doc """
  How to reach a given lobby from its ID
  """
  @spec via_tuple(Lobby.id()) :: GenServer.name()
  def via_tuple(queue_id) do
    {:via, Horde.Registry, {__MODULE__, queue_id}}
  end

  @spec lookup(Lobby.id()) :: pid() | nil
  def lookup(lobby_id) do
    case Horde.Registry.lookup(__MODULE__, lobby_id) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  @spec count() :: non_neg_integer()
  def count(), do: Horde.Registry.count(__MODULE__)

  @spec list_lobbies() :: [{Lobby.id(), pid()}]
  def list_lobbies() do
    Horde.Registry.select(__MODULE__, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
  end

  @impl true
  def init(init_args) do
    Horde.Registry.init(init_args)
  end
end
