defmodule Teiserver.Account.PartyServerTest do
  @moduledoc false
  use Teiserver.DataCase, async: true
  alias Teiserver.Account.PartyLib
  alias Teiserver.Account.Party

  test "server test" do
    id = ExULID.ULID.generate()

    p =
      PartyLib.start_party_server(%Party{
        id: id,
        leader: 1,
        members: [1],
        pending_invites: []
      })

    assert is_pid(p)

    # Check initial state
    assert :sys.get_state(p) == %{
             party: %Party{
               id: id,
               leader: 1,
               members: [1],
               pending_invites: []
             }
           }

    # Add invite
    GenServer.cast(p, {:create_invite, 2})
    GenServer.cast(p, {:create_invite, 3})
    GenServer.cast(p, {:create_invite, 4})

    assert :sys.get_state(p) == %{
             party: %Party{
               id: id,
               leader: 1,
               members: [1],
               pending_invites: [4, 3, 2]
             }
           }

    # Cancel one of them
    GenServer.cast(p, {:cancel_invite, 2})

    assert :sys.get_state(p) == %{
             party: %Party{
               id: id,
               leader: 1,
               members: [1],
               pending_invites: [4, 3]
             }
           }

    # Accept the other
    GenServer.call(p, {:accept_invite, 3})

    assert :sys.get_state(p) == %{
             party: %Party{
               id: id,
               leader: 1,
               members: [3, 1],
               pending_invites: [4]
             }
           }

    # And the last
    GenServer.call(p, {:accept_invite, 4})

    assert :sys.get_state(p) == %{
             party: %Party{
               id: id,
               leader: 1,
               members: [4, 3, 1],
               pending_invites: []
             }
           }

    # New change the leader
    GenServer.cast(p, {:new_leader, 4})

    assert :sys.get_state(p) == %{
             party: %Party{
               id: id,
               leader: 4,
               members: [4, 3, 1],
               pending_invites: []
             }
           }

    # One leaves
    GenServer.cast(p, {:member_leave, 3})

    assert :sys.get_state(p) == %{
             party: %Party{
               id: id,
               leader: 4,
               members: [4, 1],
               pending_invites: []
             }
           }

    # Kick the other
    GenServer.cast(p, {:kick_member, 1})

    assert :sys.get_state(p) == %{
             party: %Party{
               id: id,
               leader: 4,
               members: [4],
               pending_invites: []
             }
           }

    # Re-add someone
    GenServer.cast(p, {:create_invite, 1})
    GenServer.call(p, {:accept_invite, 1})

    assert :sys.get_state(p) == %{
             party: %Party{
               id: id,
               leader: 4,
               members: [1, 4],
               pending_invites: []
             }
           }

    # Leader leaves
    GenServer.cast(p, {:member_leave, 4})

    assert :sys.get_state(p) == %{
             party: %Party{
               id: id,
               leader: 1,
               members: [1],
               pending_invites: []
             }
           }

    # Last person leaves, party stops
    GenServer.cast(p, {:member_leave, 1})
    :timer.sleep(50)
    assert Process.alive?(p) == false
  end
end
