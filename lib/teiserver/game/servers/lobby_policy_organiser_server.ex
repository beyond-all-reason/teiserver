defmodule Teiserver.Game.LobbyPolicyOrganiserServer do
  @moduledoc """
  There is one organiser and they each handle one lobby management config.
  """
  alias Phoenix.PubSub
  alias Teiserver.Game
  alias Teiserver.Game.LobbyPolicyLib
  use GenServer
  require Logger

  @tick_interval 10_000
  @check_delay 5_000

  @impl true
  def handle_cast(%{event: :bot_status_update} = msg, state) do
    status = %{
      updated_at: System.system_time(:second),
      status: msg.status
    }
    new_agent_status = Map.put(state.agent_status, msg.name, status)

    {:noreply, %{state | agent_status: new_agent_status}}
  end

  def handle_cast({:updated_policy, new_lobby_policy}, state) do
    # If it's being enabled or disabled, do stuff
    case {state.db_policy.enabled, new_lobby_policy.enabled} do
      {true, false} ->
        PubSub.broadcast(
          Central.PubSub,
          "lobby_policy_internal:#{state.id}",
          %{
            channel: "lobby_policy_internal:#{state.id}",
            event: :disconnect
          }
        )
        :ok

      _ ->
        PubSub.broadcast(
          Central.PubSub,
          "lobby_policy_internal:#{state.id}",
          %{
            channel: "lobby_policy_internal:#{state.id}",
            event: :updated_policy,
            new_lobby_policy: new_lobby_policy
          }
        )
        :ok
    end

    {:noreply, %{state | db_policy: new_lobby_policy}}
  end

  @impl true
  def handle_info(%{channel: "lobby_policy_internal:" <> _}, state) do
    {:noreply, state}
  end

  def handle_info(:check_agents, state) do
    if Enum.empty?(state.agent_status) do
      spawn_agent(state)
    else
      :ok
    end

    {:noreply, state}
  end

  def handle_info(:tick, %{db_policy: %{enabled: false}} = state) do
    {:noreply, state}
  end

  def handle_info(:tick, state) do
    PubSub.broadcast(
      Central.PubSub,
      "lobby_policy_internal:#{state.id}",
      %{
        channel: "lobby_policy_internal:#{state.id}",
        event: :request_status_update
      }
    )

    # Check the agents after they've all had a chance to check in
    Process.send_after(self(), :check_agents, @check_delay)

    {:noreply, %{state | agent_status: %{}}}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp spawn_agent(state) do
    existing_names = state.agent_status
      |> Map.keys()

    remaining_names = state.db_policy.agent_name_list
      |> Enum.reject(fn name -> Enum.member?(existing_names, name) end)

    case remaining_names do
      [] ->
        :no_names
      _ ->
        selected_name = Enum.random(remaining_names)
        user = LobbyPolicyLib.get_or_make_agent_user(selected_name, state.db_policy)
        LobbyPolicyLib.start_lobby_policy_bot(state.db_policy, selected_name, user)
    end
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(data) do
    id = data.lobby_policy.id

    Logger.metadata([request_id: "LobbyPolicyOrganiserServer##{id}/#{data.lobby_policy.name}"])

    :ok = PubSub.subscribe(Central.PubSub, "lobby_policy_internal:#{id}")

    Horde.Registry.register(
      Teiserver.LobbyPolicyRegistry,
      "LobbyPolicyOrganiserServer:#{id}",
      id
    )

    :timer.send_interval(@tick_interval, :tick)

    state = %{
      id: id,
      db_policy: data.lobby_policy,
      agent_status: %{}
    }

    {:ok, state}
  end
end
