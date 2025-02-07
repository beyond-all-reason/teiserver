defmodule Teiserver.Autohost.AutohostTest do
  use ExUnit.Case, async: false

  alias Teiserver.Autohost

  describe "find autohost" do
    test "no autohost available" do
      assert nil == Autohost.find_autohost()
    end

    test "one available autohost" do
      register_autohost(123, 10, 1)
      assert 123 == Autohost.find_autohost()
    end

    test "no capacity" do
      register_autohost(123, 0, 2)
      assert nil == Autohost.find_autohost()
    end

    test "look at all autohosts" do
      register_autohost(123, 0, 10)
      register_autohost(456, 10, 2)
      assert 456 == Autohost.find_autohost()
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
