defmodule Teiserver.Agents.PartyjoinAgentServer do
  use GenServer
  alias Teiserver.Agents.AgentLib
  alias Teiserver.{Account, User}
  require Logger

  @tick_period 5_000

  def handle_info(:startup, state) do
    :timer.sleep(500)

    socket = AgentLib.get_socket()
    {:success, user} = AgentLib.login(socket, %{
      name: "Partyjoin_#{state.name}",
      email: "Partyjoin_#{state.name}@agents"
    })

    # Add friendships to all existing partyhosts
    Account.list_users(
      search: [
        name_like: "Partyhost"
      ],
      select: [:id]
    )
    |> Enum.each(fn host_user ->
      User.create_friendship(user.id, host_user.id)
    end)

    :timer.send_interval(@tick_period, self(), :tick)

    {:noreply, %{state | socket: socket}}
  end

  def handle_info(:tick, state) do
    state = cond do
      state.party_invites == [] ->
        state

      state.party_id == nil ->
        [party_id | new_invites] = Enum.shuffle(state.party_invites)
        AgentLib._send(state.socket, %{cmd: "c.party.accept", party_id: party_id})

        %{state | party_id: party_id, party_invites: new_invites}

      true ->
        if :rand.uniform(5) == 1 do
          [party_id | new_invites] = Enum.shuffle(state.party_invites)
          AgentLib._send(state.socket, %{cmd: "c.party.accept", party_id: party_id})

          %{state | party_id: party_id, party_invites: new_invites}
        else
          state
        end
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

  defp handle_msg(%{"cmd" => "s.party.accept", "party" => %{"id" => party_id}}, state) do
    %{state | party_id: party_id}
  end

  # Already a member can trigger a variant of this
  defp handle_msg(%{"cmd" => "s.party.accept"}, state), do: state

  defp handle_msg(%{"cmd" => "s.party.invite", "party" => %{"id" => party_id}}, state) do
    %{state | party_invites: [party_id | state.party_invites] |> Enum.uniq}
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
       lobby_id: nil,
       party_id: nil,
       party_invites: [],
       socket: nil
     }}
  end
end
