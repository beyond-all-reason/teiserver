defmodule Teiserver.Autohost.AutohostTest do
  use Teiserver.DataCase, async: false
  import Teiserver.Support.Polling, only: [poll_until: 2, poll_until_nil: 1]

  alias Teiserver.Autohost

  setup do
    ExUnit.Callbacks.start_supervised!(Teiserver.Tachyon.System)
    :ok
  end

  describe "find autohost" do
    test "no autohost available" do
      assert nil == Autohost.find_autohost()
    end

    test "one available autohost" do
      register_autohost(123, 10, 1)
      poll_until(&Autohost.find_autohost/0, &(&1 == 123))
    end

    test "no capacity" do
      register_autohost(123, 0, 2)
      poll_until_nil(&Autohost.find_autohost/0)
    end

    test "look at all autohosts" do
      register_autohost(123, 0, 10)
      register_autohost(456, 10, 2)
      poll_until(&Autohost.find_autohost/0, &(&1 == 456))
    end
  end

  defp register_autohost(id, max, current) do
    Autohost.Registry.register(%{id: id, max_battles: max, current_battles: current})
  end
end
