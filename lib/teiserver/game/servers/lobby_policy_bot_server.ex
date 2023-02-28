defmodule Teiserver.Game.LobbyPolicyBotServer do
  @moduledoc """
  The LobbyPolicyBots are the accounts present in each managed lobby and involved in managing that lobby specifically
  """

  alias Phoenix.PubSub
  alias Teiserver.Game
  alias Teiserver.Game.LobbyPolicyLib
  use GenServer
  require Logger

  @tick_interval 10_000

  @impl true
  def handle_info(%{channel: "lobby_policy_internal:" <> _, event: :request_status_update}, state) do
    Game.cast_lobby_organiser(state.lobby_policy_id, %{
      event: :bot_status_update,
      name: state.user.name,
      status: 1
    })

    {:noreply, state}
  end

  def handle_info(%{channel: "lobby_policy_internal:" <> _}, state) do
    {:noreply, state}
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

    Logger.metadata([request_id: "LobbyPolicyBotServer##{id}/#{data.user.name}"])

    :ok = PubSub.subscribe(Central.PubSub, "lobby_policy_internal:#{id}")

    Horde.Registry.register(
      Teiserver.ManagedLobbyRegistry,
      "LobbyPolicyBotServer:#{id}",
      id
    )

    :timer.send_interval(@tick_interval, :tick)

    state = %{
      lobby_policy_id: data.lobby_policy_id,
      user: data.user
    }

    {:ok, state}
  end
end
