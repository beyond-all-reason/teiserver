defmodule Teiserver.Account.ClientIndexThrottle do
  @doc """
  lobby_changes lists things that have changed about the battle lobby
  player_changes lists players that have changed (added, updated or removed!)
  """
  use GenServer
  alias Phoenix.PubSub
  alias Teiserver.Client

  @update_interval 2000

  # Client
  def handle_info(%{channel: "client_inout", event: :login} = msg, state) do
    {:noreply, %{state | new_clients: [msg.userid | state.new_clients]}}
  end

  def handle_info(%{channel: "client_inout", event: :disconnect} = msg, state) do
    {:noreply, %{state | new_clients: [msg.userid | state.new_clients]}}
  end

  def handle_info(%{channel: "client_inout"}, state) do
    {:noreply, state}
  end

  # Battle
  def handle_info(%{channel: "teiserver_global_user_updates", client: nil}, state) do
    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_global_user_updates"} = msg, state) do
    new_clients = [msg.client.userid | state.new_clients]
    {:noreply, %{state | new_clients: new_clients}}
  end

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
        Teiserver.PubSub,
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

    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_global_user_updates")
    :ok = PubSub.subscribe(Teiserver.PubSub, "client_inout")

    Horde.Registry.register(
      Teiserver.ThrottleRegistry,
      "ClientIndexThrottle",
      :index
    )

    {:ok,
     %{
       new_clients: [],
       removed_clients: [],
       last_update: System.system_time(:second)
     }}
  end
end
