defmodule Teiserver.TelemetryServer do
  use GenServer
  alias Teiserver.Client
  alias Teiserver.Battle

  @tick_period 5000

  def handle_info(:tick, state) do
    clients = Client.list_client_ids() |> Enum.count
    battles = Battle.list_battle_ids() |> Enum.count

    :telemetry.execute([:teiserver, :client], %{count: clients}, %{})
    :telemetry.execute([:teiserver, :battle], %{count: battles}, %{})

    {:noreply, state}
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts[:data], opts)
  end

  def init(_opts) do
    :timer.send_interval(@tick_period, self(), :tick)

    {:ok, %{}}
  end
end
