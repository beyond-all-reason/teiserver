defmodule Teiserver.Telemetry.SpringTelemetryServer do
  @doc """
  A server used to track the number of messages sent out via the legacy global
  pubsub channels.
  """
  use GenServer
  alias Teiserver.Client
  alias Phoenix.PubSub

  @tick_period 5_000
  @default_state %{}

  @impl true
  def handle_info(:tick, state) do
    report_telemetry(state)

    {:noreply, %{}}
  end

  def handle_info(data, state) do
    [event | _] = Tuple.to_list(data)
    client_count = Client.list_client_ids() |> Enum.count()

    new_state = Map.put(state, event, Map.get(state, event, 0) + client_count)

    {:noreply, new_state}
  end

  # @impl true
  # def handle_call(:get_state, _from, state) do
  #   {:reply, state, state}
  # end

  @spec report_telemetry(Map.t()) :: :ok
  defp report_telemetry(state) do
    :telemetry.execute([:spring], state, %{})
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts[:data], opts)
  end

  @impl true
  def init(_opts) do
    :timer.send_interval(@tick_period, self(), :tick)

    :ok = PubSub.subscribe(Central.PubSub, "legacy_all_user_updates")
    :ok = PubSub.subscribe(Central.PubSub, "legacy_all_battle_updates")
    :ok = PubSub.subscribe(Central.PubSub, "legacy_all_client_updates")

    {:ok, @default_state}
  end
end
