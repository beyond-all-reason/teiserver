defmodule Teiserver.Agents.PartyhostAgentServer do
  use GenServer
  alias Teiserver.User
  alias Teiserver.Agents.AgentLib
  require Logger

  @tick_period 5_000

  def handle_info(:startup, state) do
    socket = AgentLib.get_socket()
    {:success, user} = AgentLib.login(socket, %{
      name: "Partyhost_#{state.name}",
      email: "Partyhost_#{state.name}@agents"
    })

    # Create friendships between this user and the first 10 users to exist
    # currently has a bug because it'll try to update several at once and it won't work
    0..10
    |> Enum.each(fn other_user_id ->
      User.create_friendship(user.id, other_user_id)
    end)

    :timer.sleep(:rand.uniform(1000))

    :timer.send_interval(@tick_period, self(), :tick)

    {:noreply, %{state | socket: socket}}
  end

  def handle_info(:tick, state) do
    if state.party_id == nil do
      AgentLib._send(state.socket, %{cmd: "c.party.create"})
    else
      AgentLib._send(state.socket, %{cmd: "c.user.list_friend_users_and_clients"})
    end

    {:noreply, state}
  end

  def handle_info({:ssl, _socket, data}, state) do
    new_state = data
      |> AgentLib.translate
      |> Enum.reduce(state, fn data, acc ->
        handle_msg(data, acc)
      end)

    {:noreply, new_state}
  end

  defp handle_msg(nil, state), do: state
  defp handle_msg(%{"cmd" => "s.party.updated"}, state), do: state
  defp handle_msg(%{"cmd" => "s.party.create", "party" => party}, state) do
    %{state | party_id: party["id"]}
  end

  defp handle_msg(%{"cmd" => "s.user.list_friend_users_and_clients", "client_list" => clients}, state) do
    clients
      |> Enum.reject(fn c -> c["party_id"] == state.party_id end)
      |> Enum.each(fn c ->
        AgentLib._send(state.socket, %{cmd: "c.party.invite", userid: c["userid"]})
      end)

    state
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts[:data], opts)
  end

  def init(opts) do
    send(self(), :startup)

    {:ok,
     %{
       id: opts.id,
       number: opts.number,
       name: Map.get(opts, :name, opts.number),
       party_id: nil,
       socket: nil
     }}
  end
end
