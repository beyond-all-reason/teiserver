defmodule Teiserver.Director.ConsulServer do
  use GenServer
  require Logger
  alias Teiserver.{Director, Client, User}
  alias Teiserver.Battle.BattleLobby
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def handle_call(:get_all, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  def handle_call({:request_user_join_battle, _userid}, _from, state) do
    # TODO: Implement user access control as a function of the consul
    {:reply, true, state}
  end

  # Infos
  def handle_info({:put, key, value}, state) do
    new_state = Map.put(state, key, value)
    {:noreply, new_state}
  end

  def handle_info({:merge, new_map}, state) do
    new_state = Map.merge(state, new_map)
    {:noreply, new_state}
  end

  # Doesn't do anything at this stage
  def handle_info(:startup, state) do
    {:noreply, state}
  end

  def handle_info({:user_joined, userid}, state) do
    if state.welcome_message do
      username = User.get_username(userid)
      BattleLobby.sayprivateex(state.coordinator_id, userid, "#{username}: " <> state.welcome_message, state.battle_id)
    end

    {:noreply, state}
  end

  def handle_info(%{command: _} = cmd, state) do
    new_state = if allow?(cmd, state) do
      handle_command(cmd, state)
    else
      state
    end
    {:noreply, new_state}
  end

  @doc """
    Command has structure:
    %{
      raw: string,
      remaining: string,
      vote: boolean,
      command: nil | string,
      senderid: userid
    }
  """
  def handle_command(%{command: "welcome-message", remaining: remaining} = _cmd, state) do
    case String.trim(remaining) do
      "" ->
        %{state | welcome_message: nil}
      msg ->
        %{state | welcome_message: msg}
    end
  end

  def handle_command(%{command: "director", remaining: "stop"} = cmd, state) do
    BattleLobby.stop_director_mode(state.battle_id)
    state
  end

  def handle_command(%{command: "force-spectator", remaining: target_id} = cmd, state) do
    BattleLobby.force_change_client(state.coordinator_id, int_parse(target_id), :player, false)
    state
  end

  def handle_command(%{command: command} = _cmd, state) do
    Logger.error("No handler in consul_server for command type '#{command}'")
    state
  end

  defp allow?(%{senderid: senderid} = _cmd, _state) do
    client = Client.get_client_by_id(senderid)
    client.moderator
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    {:ok,
     %{
       coordinator_id: Director.get_coordinator_userid(),
       battle_id: opts[:battle_id],
       welcome_message: nil
     }}
  end
end
