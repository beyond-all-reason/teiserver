defmodule Teiserver.Game.LobbyPolicyBotServer do
  @moduledoc """
  The LobbyPolicyBots are the accounts present in each managed lobby and involved in managing that lobby specifically
  """

  alias Phoenix.PubSub
  alias Teiserver.{Game, User, Client}
  alias Teiserver.Battle.Lobby
  # alias Teiserver.Game.LobbyPolicyLib
  alias Teiserver.Data.Types, as: T
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

  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :added_to_lobby, lobby_id: lobby_id}, state) do
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")

    PubSub.subscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    PubSub.subscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")

    {:noreply, %{state | lobby_id: lobby_id}}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :client_updated}, state) do
    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :force_join_lobby}, state) do
    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _} = m, state) do
    Logger.error("Error at: #{__ENV__.file}:#{__ENV__.line}\n#{inspect m.event}")
    {:noreply, state}
  end

  # No lobby, need to find one!
  def handle_info(:tick, %{lobby_id: nil} = state) do
    # TODO: Use the coordinator to request a new lobby be hosted by SPADS
    empty_lobby = Lobby.find_empty_lobby(fn l ->
      (String.starts_with?(l.name, "EU ") or String.starts_with?(l.name, "BH "))
      and
      l.password == nil
    end)

    case empty_lobby do
      nil ->
        Logger.info("LobbyPolicyBotServer find_empty_lobby was unable to find an empty lobby")
        {:noreply, state}

      _ ->
        Lobby.force_add_user_to_lobby(state.userid, empty_lobby.id)

        Logger.info("LobbyPolicyBotServer found an empty lobby")
        {:noreply, %{state | lobby_id: empty_lobby.id}}
    end
  end

  # Lobby chat
  def handle_info({:lobby_update, _action, _lobby_id, _data}, state) do
    # IO.inspect {action, data}, label: "lobby_update"
    {:noreply, state}
  end

  # Lobby chat
  def handle_info(%{channel: "teiserver_lobby_chat:" <> _, userid: userid, message: message}, state) do
    new_state = handle_chat(userid, message, state)
    {:noreply, new_state}
  end

  def handle_info(:tick, state) do
    {:noreply, state}
  end

  def handle_info({:force_join_battle, _, _}, state) do
    {:noreply, state}
  end

  @spec handle_chat(T.userid(), String.t(), map()) :: map()
  defp handle_chat(_senderid, _message, state) do
    state
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
