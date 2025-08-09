defmodule Teiserver.TachyonLobby.Lobby do
  @moduledoc """
  Represent a single lobby
  """

  use GenServer, restart: :transient

  alias Teiserver.TachyonLobby

  @type id :: String.t()

  @type state :: %{
          id: id()
        }

  @spec gen_id() :: id()
  def gen_id(), do: UUID.uuid4()

  @spec start_link(state()) :: GenServer.on_start()
  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state,
      name: via_tuple(initial_state.id)
    )
  end

  @impl true
  def init(initial_state) do
    Logger.metadata(actor_type: :lobby, actor_id: initial_state.id)

    {:ok, initial_state}
  end

  @spec via_tuple(id()) :: GenServer.name()
  defp via_tuple(lobby_id) do
    TachyonLobby.Registry.via_tuple(lobby_id)
  end
end
