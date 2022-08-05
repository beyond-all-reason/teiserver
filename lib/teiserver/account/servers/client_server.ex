defmodule Teiserver.Account.ClientServer do
  use GenServer
  require Logger
  alias Teiserver.Battle.LobbyChat
  # alias Teiserver.{Account}

  @impl true
  def handle_call(:get_client_state, _from, state) do
    {:reply, state.client, state}
  end

  @impl true
  def handle_cast({:update_values, new_values}, state) do
    new_client = Map.merge(state.client, new_values)
    {:noreply, %{state | client: new_client}}
  end

  def handle_cast({:merge_update_client, partial_client}, state) do
    new_client = Map.merge(state.client, partial_client)
    {:noreply, %{state | client: new_client}}
  end

  def handle_cast({:update_client, new_client}, state) do
    if state.client.player != new_client.player do
      if new_client.player do
        LobbyChat.persist_system_message("#{state.client.name} became a player", state.client.lobby_id)
      else
        LobbyChat.persist_system_message("#{state.client.name} became a spectator", state.client.lobby_id)
      end
    end

    new_client = Map.merge(state.client, new_client)
    {:noreply, %{state | client: new_client}}
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(state = %{client: %{userid: userid}}) do
    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.ClientRegistry,
      userid,
      state.client.lobby_client
    )

    {:ok, Map.merge(state, %{
      userid: userid
    })}
  end
end
