defmodule Teiserver.Account.PartyServer do
  use GenServer
  require Logger
  # alias Teiserver.{Account}

  @impl true
  def handle_call(:get_party_state, _from, state) do
    {:reply, state.party, state}
  end

  @impl true
  def handle_cast({:update_party, new_party}, state) do
    {:noreply, %{state | party: new_party}}
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(state = %{party: %{userid: userid}}) do
    Horde.Registry.register(
      Teiserver.PartyRegistry,
      userid,
      state.party.id
    )

    {:ok, Map.merge(state, %{
      userid: userid
    })}
  end
end
