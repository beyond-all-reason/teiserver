defmodule Teiserver.Helper.MonitorCollectionTest do
  use ExUnit.Case, async: true

  defmodule GenServerTest do
    use GenServer

    def start_link(arg), do: GenServer.start_link(__MODULE__, arg)

    @impl true
    def init(_args), do: {:ok, nil}

    @impl true
    def handle_call(:stop, _from, state), do: {:stop, :normal, :stopped, state}
  end

  alias Teiserver.Helpers.MonitorCollection, as: MC
  import ExUnit.Callbacks, only: [start_supervised!: 1]

  test "can monitor a single process" do
    pid = start_supervised!(GenServerTest)
    mc = MC.new() |> MC.monitor(pid, :val)

    GenServer.call(pid, :stop)
    assert_receive {:DOWN, ref, :process, _, _}, 10

    assert MC.get_val(mc, ref) == :val
    assert MC.get_ref(mc, :val) == ref
  end

  test "can demonitor by val" do
    pid = start_supervised!(GenServerTest)
    mc = MC.new() |> MC.monitor(pid, :val) |> MC.demonitor_by_val(:val)
    assert MC.get_ref(mc, :val) == nil

    GenServer.call(pid, :stop)

    refute_receive {:DOWN, _, :process, _, _}, 10
  end

  test "can update value without losing ref" do
    pid = start_supervised!(GenServerTest)

    mc =
      MC.new()
      |> MC.monitor(pid, :val)
      |> MC.replace_val!(:val, :newval)

    assert MC.get_ref(mc, :val) == nil
    assert is_reference(MC.get_ref(mc, :newval))

    MC.demonitor_by_val(mc, :newval)
    GenServer.call(pid, :stop)

    refute_receive {:DOWN, _, :process, _, _}, 10
  end
end
