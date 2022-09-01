defmodule Teiserver.Telemetry.SpringTelemetryServer do
  @doc """
  A server used to track the number of messages sent out via the legacy global
  pubsub channels.
  """
  use GenServer
  alias Teiserver.Client
  alias Phoenix.PubSub

  @client_count_tick 500
  @tick_period 5_000
  @default_state %{
    client_count: 0,
    raw: %{},
    mult: %{}
  }

  @impl true
  def handle_info(:tick, state) do
    report_telemetry(state)

    {:noreply, %{state | raw: %{}, mult: %{}}}
  end

  def handle_info(:client_count_tick, state) do
    client_count = Client.list_client_ids() |> Enum.count()
    new_state = %{state | client_count: client_count}

    {:noreply, new_state}
  end

  def handle_info(data, state) do
    data_type = elem(data, 0)

    event = case data_type do
      :updated_client ->
        case elem(data, 2) do
          :silent -> nil
          :client_updated_battlestatus -> :battlestatus
          :client_updated_status -> :mystatus
        end
      e -> e
    end

    if event != nil do
      new_raw = Map.put(state.raw, event, Map.get(state.raw, event, 0) + 1)
      new_mult = Map.put(state.mult, event, Map.get(state.mult, event, 0) + state.client_count)

      new_state = %{state | raw: new_raw, mult: new_mult}

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @spec report_telemetry(Map.t()) :: :ok
  defp report_telemetry(state) do
    :telemetry.execute([:spring_raw], state.raw, %{})
    :telemetry.execute([:spring_mult], state.mult, %{})
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts[:data], opts)
  end

  @impl true
  def init(_opts) do
    :timer.send_interval(@tick_period, self(), :tick)
    :timer.send_interval(@client_count_tick, self(), :client_count_tick)

    :ok = PubSub.subscribe(Central.PubSub, "legacy_all_user_updates")
    :ok = PubSub.subscribe(Central.PubSub, "legacy_all_battle_updates")
    :ok = PubSub.subscribe(Central.PubSub, "legacy_all_client_updates")

    client_count = Client.list_client_ids() |> Enum.count()
    state = %{@default_state | client_count: client_count}

    {:ok, state}
  end
end
