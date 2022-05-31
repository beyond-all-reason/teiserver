defmodule Teiserver.Battle.LobbyServer do
  use GenServer
  require Logger
  # alias Phoenix.PubSub

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(%{lobby: state}) do
    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.LobbyRegistry,
      state.id,
      state.id
    )

    {:ok, state}
  end
end
