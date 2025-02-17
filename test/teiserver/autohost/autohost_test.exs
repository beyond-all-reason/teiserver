defmodule Teiserver.Autohost.AutohostTest do
  use ExUnit.Case, async: false
  import Teiserver.Support.Tachyon, only: [poll_until: 2, poll_until_nil: 1]

  alias Teiserver.Autohost

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

    # Teiserver.Support.Tachyon.poll_until_some(fn ->
    #   Autohost.Registry.lookup(id)
    # end)

    on_exit(fn ->
      Autohost.Registry.unregister(id)

      Teiserver.Support.Tachyon.poll_until_nil(fn ->
        Autohost.Registry.lookup(id)
      end)
    end)
  end
end
