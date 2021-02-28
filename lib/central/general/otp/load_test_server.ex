defmodule Central.General.LoadTest.Server do
  use GenServer

  alias Central.General.LoadTest.Stats
  # import Central.Helpers.NumberHelper, only: [int_parse: 1]
  import Central.Helpers.FileHelper, only: [mem_normalize: 1]

  @tester_timeout 3_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def register_tester(%{"uid" => uid, "agent" => agent}) do
    GenServer.cast(__MODULE__, {:register_tester, uid, agent})
  end

  def tester_broadcast(params) do
    GenServer.cast(__MODULE__, {:tester_broadcast, params})
  end

  def new_stats(params) do
    GenServer.cast(__MODULE__, {:new_stats, params})
  end

  def tester_ping_update(%{"uid" => uid, "time_taken" => time_taken}) do
    Stats.log_tester_ping(uid, time_taken)
  end

  def get_testers() do
    GenServer.call(__MODULE__, :get_testers)
  end

  # GenServer callbacks
  def handle_call(:get_testers, _from, state) do
    {:reply, state, state}
  end

  def handle_cast(
        {:tester_broadcast, %{"text" => _text, "uid" => uid, "agent" => broadcast_agent}},
        state
      ) do
    state =
      state
      |> Enum.filter(fn {tester_id, _agent, last_seen} ->
        tester_id != uid and systime() - last_seen < @tester_timeout
      end)
      |> List.insert_at(-1, {uid, broadcast_agent, systime()})

    spawn(fn ->
      rebroadcast(uid, state)
    end)

    {:noreply, state}
  end

  def handle_cast({:new_stats, params}, state) do
    total_ping =
      params.response_times
      |> Enum.reduce(0, fn {_, ping}, acc -> acc + ping end)

    message_count = Enum.count(params.response_times)

    payload =
      Map.merge(params, %{
        response_times: nil,
        testers: Enum.count(params.testers),
        average_ping: if(message_count == 0, do: 0, else: total_ping / message_count),
        message_count: message_count,
        ram: (params.ram * 1024) |> mem_normalize,
        cpu: Enum.join(params.loads, ", ")
      })

    spawn(fn ->
      send_stats(payload, state)
    end)

    {:noreply, state}
  end

  def handle_cast({:register_tester, uid, agent}, state) do
    state =
      state
      |> List.insert_at(-1, {uid, agent, systime()})

    {:noreply, state}
  end

  defp send_stats(payload, state) do
    state
    |> Enum.each(fn {tester_id, _agent, _last_seen} ->
      CentralWeb.Endpoint.broadcast(
        "load_test:tester:#{tester_id}",
        "new stats",
        payload
      )
    end)
  end

  defp rebroadcast(uid, state) do
    tester_count = Enum.count(state)

    state
    |> Enum.each(fn {tester_id, _agent, _last_seen} ->
      CentralWeb.Endpoint.broadcast(
        "load_test:tester:#{tester_id}",
        "new message",
        %{
          "sender" => uid,
          "message" => "#{tester_count} - That's how many testers there currently are!"
        }
      )
    end)

    Stats.messages_sent(tester_count)
  end

  defp systime() do
    :os.system_time(:millisecond)
  end

  def init(_args) do
    {:ok, []}
  end
end
