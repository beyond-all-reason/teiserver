defmodule Central.General.LoadTest.Stats do
  use GenServer

  alias Central.Repo
  alias Central.General.LoadTestStat
  alias Central.General.LoadTest.Server
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  # import Central.Helpers.FileHelper, only: [mem_normalize: 1]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def register_tester(uid, agent) do
    GenServer.cast(__MODULE__, {:register_tester, uid, agent})
  end

  def log_tester_ping(uid, ping) do
    GenServer.cast(__MODULE__, {:log_tester_ping, uid, ping})
  end

  def messages_sent(message_count) do
    GenServer.cast(__MODULE__, {:messages_sent, message_count})
  end

  # GenServer callbacks
  # Currently trying to work out how best to handle testers and their user-agents since it's only registered when they first join. Currently thinking I need to track their agent along with their last seen and then have Server periodically send the list to Stats.
  def handle_info(:second_tick, state) do
    # Get loads
    [_, l1, l5, l15] =
      ~r/load average: ([0-9\.]+), ([0-9\.]+), ([0-9\.]+)/
      |> Regex.run(:os.cmd('uptime') |> to_string)

    # Get RAM
    [_, raw_ram] =
      ~r/([0-9]+) K used memory/
      |> Regex.run(:os.cmd('vmstat -s') |> to_string)

    ram =
      raw_ram
      |> int_parse

    # |> (fn v -> v * 1024 end).()
    # |> mem_normalize

    state =
      Map.merge(state, %{
        loads: [l1, l5, l15],
        ram: ram,
        time: Timex.now()
      })

    Server.new_stats(state)
    log_stats(state)
    {:noreply, blank_stats()}
  end

  def handle_cast({:register_tester, uid, agent}, state) do
    state = Map.put(state, :testers, [{uid, agent} | state.testers])

    {:noreply, state}
  end

  def handle_cast({:log_tester_ping, uid, ping}, state) do
    state = Map.put(state, :response_times, [{uid, ping} | state.response_times])

    {:noreply, state}
  end

  # These are summed up so we know how many we sent over the period
  def handle_cast({:messages_sent, count}, state) do
    state = Map.put(state, :messages_sent, state.messages_sent + count)

    {:noreply, state}
  end

  # We want to average these over the course of the period
  def handle_cast({:tester_count, count}, state) do
    state = Map.put(state, :tester_count, count)

    {:noreply, state}
  end

  defp blank_stats() do
    %{
      messages_sent: 0,
      tester_count: [],
      testers: Server.get_testers(),
      response_times: []
    }
  end

  defp log_stats(state) do
    [l1, l5, l15] =
      state.loads
      |> Enum.map(fn l ->
        {r, _} = Float.parse(l)
        r
      end)

    # agent_lookup = state.testers
    # |> Enum.map(fn {uid, agent, _last_seen} -> {uid, agent} end)
    # |> Map.new

    response_times =
      state.response_times
      |> Enum.map(fn {_uid, t} -> t end)

    agents =
      state.testers
      |> Enum.map(fn {_uid, agent, _last_seen} -> agent end)
      |> Enum.uniq()

    attrs =
      Map.merge(state, %{
        l1: l1,
        l5: l5,
        l15: l15,
        tester_count: Enum.count(state.testers),
        response_count: Enum.count(state.response_times),
        response_times: response_times,
        agents: agents
      })
      |> Map.drop([:loads, :testers, :time])

    if Enum.count(state.testers) > 0 do
      %LoadTestStat{}
      |> LoadTestStat.changeset(%{timeid: Timex.now(), data: attrs})
      |> Repo.insert()
    end
  end

  def init(_args) do
    :timer.send_interval(1_000, self(), :second_tick)
    {:ok, blank_stats()}
  end
end
