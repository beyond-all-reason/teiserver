defmodule Teiserver.Autohost.SessionRegistryTest do
  alias Teiserver.Autohost.SessionRegistry
  alias Teiserver.Autohost.Types, as: AT

  use Teiserver.DataCase, async: false

  @moduletag :tachyon

  test "set value also register" do
    SessionRegistry.set_value(%AT.Overview{id: 1, max_battles: 20, current_battles: 10})

    assert SessionRegistry.get_value(1) == %AT.Overview{
             id: 1,
             max_battles: 20,
             current_battles: 10
           }
  end

  test "can lookup" do
    SessionRegistry.set_value(%AT.Overview{id: 1, max_battles: 20, current_battles: 10})
    {_pid, %AT.Overview{id: 1, max_battles: 20, current_battles: 10}} = SessionRegistry.lookup(1)
  end

  test "list all registered sessions" do
    SessionRegistry.set_value(%AT.Overview{id: 1, max_battles: 20, current_battles: 10})
    SessionRegistry.set_value(%AT.Overview{id: 2, max_battles: 1, current_battles: 1})

    expected = [
      %AT.Overview{id: 1, max_battles: 20, current_battles: 10},
      %AT.Overview{id: 2, max_battles: 1, current_battles: 1}
    ]

    assert Enum.sort_by(SessionRegistry.list(), & &1.id) == expected
  end
end
