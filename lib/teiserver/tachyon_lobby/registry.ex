defmodule Teiserver.TachyonLobby.Registry do
  alias Teiserver.TachyonLobby.Lobby

  def child_spec(_) do
    Supervisor.child_spec(Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end

  def start_link() do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  How to reach a given lobby from its ID
  """
  @spec via_tuple(Lobby.id()) :: GenServer.name()
  def via_tuple(queue_id) do
    {:via, Registry, {__MODULE__, queue_id}}
  end

  @spec lookup(Lobby.id()) :: pid() | nil
  def lookup(lobby_id) do
    case Registry.lookup(__MODULE__, lobby_id) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  @spec count() :: non_neg_integer()
  def count() do
    Registry.count(__MODULE__)
  end

  @spec list_lobbies() :: [{Lobby.id(), pid()}]
  def list_lobbies() do
    Registry.select(__MODULE__, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
  end
end
