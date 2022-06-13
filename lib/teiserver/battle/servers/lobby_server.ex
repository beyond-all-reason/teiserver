defmodule Teiserver.Battle.LobbyServer do
  use GenServer
  require Logger
  alias Teiserver.{Battle, Client}
  alias Phoenix.PubSub

  @impl true
  def handle_call(:get_lobby_state, _from, state) do
    {:reply, %{state.lobby | players: state.member_list}, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  def handle_call({:get_player, _player_id}, _from, %{state: :lobby} = state) do
    {:reply, :lobby, state}
  end

  def handle_call({:get_player, player_id}, _from, %{player_list: player_list} = state) do
    found = player_list
      |> Enum.filter(fn p -> p.userid == player_id end)

    result = case found do
      [player] -> player
      _ -> nil
    end

    {:reply, result, state}
  end

  def handle_call(:get_member_list, _from, state) do
    {:reply, state.member_list, state}
  end

  def handle_call(:get_member_count, _from, state) do
    {:reply, Enum.count(state.member_list), state}
  end

  def handle_call(:get_player_list, _from, %{state: :lobby} = state) do
    {:reply, :lobby, state}
  end

  def handle_call(:get_player_list, _from, state) do
    {:reply, state.player_list, state}
  end

  def handle_call(:get_player_count, _from, %{state: :lobby} = state) do
    {:reply, :lobby, state}
  end

  def handle_call(:get_player_count, _from, state) do
    {:reply, Enum.count(state.player_list), state}
  end

  @impl true
  def handle_cast(:start_match, state) do
    player_list = state.lobby_id
      |> Battle.get_lobby()
      |> Map.get(:players)
      |> Enum.map(fn userid -> Client.get_client_by_id(userid) end)
      |> Enum.filter(fn client -> client != nil end)
      |> Enum.filter(fn client -> client.player == true and client.lobby_id == state.lobby_id end)

    {:noreply, %{state | player_list: player_list, state: :in_progress}}
  end

  def handle_cast(:stop_match, state) do
    {:noreply, %{state | player_list: [], state: :lobby}}
  end

  def handle_cast({:add_user, userid, _script_password}, state) do
    new_members = [userid | state.member_list] |> Enum.uniq
    {:noreply, %{state | member_list: new_members}}
  end

  def handle_cast({:remove_user, userid}, state) do
    new_members = List.delete(state.member_list, userid)
    {:noreply, %{state | member_list: new_members}}
  end

  def handle_cast({:update_value, key, value}, state) do
    new_lobby = Map.put(state.lobby, key, value)
    {:noreply, %{state | lobby: new_lobby}}
  end

  def handle_cast({:update_lobby, new_lobby}, state) do
    {:noreply, %{state | lobby: new_lobby}}
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(state = %{lobby: %{id: lobby_id}}) do
    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.LobbyRegistry,
      lobby_id,
      lobby_id
    )

    {:ok, Map.merge(state, %{
      lobby_id: lobby_id,
      member_list: [],
      player_list: [],
      state: :lobby
    })}
  end
end
