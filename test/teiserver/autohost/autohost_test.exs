defmodule Teiserver.Autohost.AutohostTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.Autohost

  test "can create autohost" do
    {:ok, autohost} = Autohost.create_autohost(%{name: "autohost_test"})
    assert autohost != nil
    assert Autohost.get_autohost(autohost.id) == autohost
  end
end
