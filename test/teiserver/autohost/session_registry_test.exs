defmodule Teiserver.Autohost.SessionRegistryTest do
  use Teiserver.DataCase, async: false

  @moduletag :tachyon

  alias Teiserver.Autohost.SessionRegistry

  test "set value also register" do
    SessionRegistry.set_value(1, 20, 10)
    assert SessionRegistry.get_value(1) == %{id: 1, max_battles: 20, current_battles: 10}
  end

  test "can lookup" do
    SessionRegistry.set_value(1, 20, 10)
    {_, %{id: 1, max_battles: 20, current_battles: 10}} = SessionRegistry.lookup(1)
  end

  test "list all registered sessions" do
    SessionRegistry.set_value(1, 20, 10)
    SessionRegistry.set_value(2, 1, 1)

    expected = [
      %{id: 1, max_battles: 20, current_battles: 10},
      %{id: 2, max_battles: 1, current_battles: 1}
    ]

    assert SessionRegistry.list() == expected
  end
end
