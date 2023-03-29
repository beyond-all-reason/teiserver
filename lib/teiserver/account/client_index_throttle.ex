defmodule Teiserver.Account.ClientIndexThrottle do
  @doc """
  lobby_changes lists things that have changed about the battle lobby
  player_changes lists players that have changed (added, updated or removed!)
  """
  use GenServer
  alias Phoenix.PubSub
  alias Teiserver.Client

  @update_interval 2000

  # Users
  def handle_info({:user_logged_in, userid}, state) do
    {:noreply, %{state | new_clients: [userid | state.new_clients]}}
  end

  def handle_info({:user_logged_out, userid, _name}, state) do
    {:noreply, %{state | removed_clients: [userid | state.removed_clients]}}
  end

  # Client
  def handle_info({:updated_client, %{userid: userid}, _reason}, state) do
    {:noreply, %{state | new_clients: [userid | state.new_clients]}}
  end

  # Battle
  def handle_info({:add_user_to_battle, userid, _, _}, state) do
    {:noreply, %{state | new_clients: [userid | state.new_clients]}}
  end

  def handle_info({:remove_user_from_battle, userid, _}, state) do
    {:noreply, %{state | new_clients: [userid | state.new_clients]}}
  end

  def handle_info({:kick_user_from_battle, userid, _}, state) do
    {:noreply, %{state | new_clients: [userid | state.new_clients]}}
  end

  def handle_info({:global_battle_updated, _, _}, state), do: {:noreply, state}

  # Doesn't do anything at this stage
  def handle_info(:startup, state) do
    {:noreply, state}
  end

  def handle_info(:tick, %{new_clients: [], removed_clients: []} = state), do: {:noreply, state}

  def handle_info(:tick, state) do
    {:noreply, broadcast(state)}
  end

  defp broadcast(state) do
    new_clients_map =
      state.new_clients
      |> Enum.uniq()
      |> Client.get_clients()
      |> Enum.filter(&(&1 != nil))
      |> Map.new(fn c -> {c.userid, c} end)

    removed_clients =
      state.removed_clients
      |> Enum.uniq()
      |> Enum.filter(fn c ->
        not Enum.member?(state.new_clients, c)
      end)

    :ok =
      PubSub.broadcast(
        Central.PubSub,
        "teiserver_liveview_client_index_updates",
        {:client_index_throttle, new_clients_map, removed_clients}
      )

    %{state | new_clients: [], removed_clients: []}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def init(_opts) do
    send(self(), :startup)
    :timer.send_interval(@update_interval, self(), :tick)

    :ok = PubSub.subscribe(Central.PubSub, "legacy_all_user_updates")
    :ok = PubSub.subscribe(Central.PubSub, "legacy_all_client_updates")
    :ok = PubSub.subscribe(Central.PubSub, "legacy_all_battle_updates")

    Horde.Registry.register(
      Teiserver.ThrottleRegistry,
      "ClientIndexThrottle",
      :index
    )

    {:ok,
     %{
       new_clients: [],
       removed_clients: []
     }}
  end
end
