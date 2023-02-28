defmodule Teiserver.Game.LobbyPolicyBotServer do
  @moduledoc """
  The LobbyPolicyBots are the accounts present in each managed lobby and involved in managing that lobby specifically
  """

  alias Phoenix.PubSub
  alias Teiserver.{Game, User, Client}
  alias Teiserver.Battle.Lobby
  # alias Teiserver.Game.LobbyPolicyLib
  use GenServer
  require Logger

  @tick_interval 10_000

  @impl true
  def handle_info(%{channel: "lobby_policy_internal:" <> _, event: :request_status_update}, state) do
    :ok = Game.cast_lobby_organiser(state.lobby_policy_id, %{
      event: :bot_status_update,
      name: state.user.name,
      status: %{
        lobby_id: state.lobby_id
      }
    })

    {:noreply, state}
  end

  def handle_info(%{channel: "lobby_policy_internal:" <> _, event: :disconnect}, state) do
    Client.disconnect(state.userid, "Bot disconnect")
    {:noreply, state}
  end

  def handle_info(%{channel: "lobby_policy_internal:" <> _}, state) do
    {:noreply, state}
  end

  # teiserver_client_messages
  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :disconnected}, state) do
    # We've disconnected, time to kill this process
    DynamicSupervisor.terminate_child(Teiserver.LobbyPolicySupervisor, self())
    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _} = m, state) do
    {:noreply, state}
  end

  # No lobby, need to find one!
  def handle_info(:tick, %{lobby_id: nil} = state) do
    Logger.warn("Bot tick")
    # TODO: Use the coordinator to request a new lobby be hosted by SPADS
    empty_lobby = Lobby.find_empty_lobby(fn l ->
      String.starts_with?(l.name, "EU ") or String.starts_with?(l.name, "BH ")
    end)

    case empty_lobby do
      nil ->
        Logger.info("LobbyPolicyBotServer find_empty_lobby was unable to find an empty lobby")
        {:noreply, state}

      _ ->
        Logger.info("LobbyPolicyBotServer found an empty lobby")
        {:noreply, %{state | lobby_id: empty_lobby.id}}
    end
  end

  def handle_info(:tick, state) do
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(data) do
    id = data.lobby_policy_id

    :ok = PubSub.subscribe(Central.PubSub, "lobby_policy_internal:#{id}")
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_messages:#{data.userid}")

    Horde.Registry.register(
      Teiserver.LobbyPolicyRegistry,
      "LobbyPolicyBotServer:#{data.userid}",
      id
    )

    {user, _client} = case User.internal_client_login(data.userid) do
      {:ok, user, client} -> {user, client}
      :error -> raise "No user found"
    end

    Logger.metadata([request_id: "LobbyPolicyBotServer##{id}/#{user.name}"])

    :timer.send_interval(@tick_interval, :tick)

    {:ok, %{
      lobby_policy_id: data.lobby_policy_id,
      lobby_id: nil,
      userid: user.id,
      user: user
    }}
  end
end
