defmodule Teiserver.Coordinator.QuantumCommandTest do
  alias Teiserver.Account
  alias Teiserver.Account.ClientLib
  alias Teiserver.AccountFixtures
  alias Teiserver.Battle
  alias Teiserver.Client
  alias Teiserver.Coordinator
  alias Teiserver.Lobby
  alias Teiserver.Lobby.ChatLib

  use Teiserver.ServerCase, async: false

  import TeiserverTestLib,
    only: [
      auth_setup: 1,
      auth_setup: 2,
      # _recv_until: 1,
      start_spring_server: 1
    ]

  setup(_context) do
    {:ok, context} = start_spring_server(%{start_spring_server: :tcp})
    TeiserverTestLib.start_coordinator!()

    lobby_id = TeiserverTestLib.make_lobby()
    lobby = Lobby.get_lobby(lobby_id)
    host = Account.deprecated_get_user_by_id(lobby.founder_id)

    u1 =
      AccountFixtures.user_fixture(%{
        roles: ["Server", "Bot"],
        permissions: ["Server", "Bot"]
      })

    user1 = %{user: u1} = auth_setup(context, u1)
    Client.login(u1, :test, "127.0.0.1")

    user2 = %{user: u2} = auth_setup(context)
    Client.login(u2, :test, "127.0.0.2")

    user3 = %{user: u3} = auth_setup(context)
    Client.login(u3, :test, "127.0.0.3")

    user4 = %{user: u4} = auth_setup(context)
    Client.login(u4, :test, "127.0.0.4")

    Lobby.force_add_user_to_lobby(u1.id, lobby_id)
    Lobby.force_add_user_to_lobby(u2.id, lobby_id)
    Lobby.force_add_user_to_lobby(u3.id, lobby_id)
    Lobby.force_add_user_to_lobby(u4.id, lobby_id)

    ClientLib.update_client(u1.id, %{player: true, player_number: 1, team_number: 1})
    ClientLib.update_client(u2.id, %{player: true, player_number: 2, team_number: 1})
    ClientLib.update_client(u3.id, %{player: true, player_number: 3, team_number: 2})
    ClientLib.update_client(u4.id, %{player: true, player_number: 4, team_number: 2})

    {:ok, lobby_id: lobby_id, host: host, user1: user1, user2: user2, user3: user3, user4: user4}
  end

  defp setup_lobby(%{lobby_id: lobby_id, host: host}) do
    Coordinator.send_consul(lobby_id, {:host_update, host.id, %{host_bosses: [host.id]}})

    on_exit(fn ->
      Lobby.close_lobby(lobby_id)
    end)

    {:ok, lobby_id: lobby_id, host: host}
  end

  describe "Quantum mode" do
    setup [:setup_lobby]

    test "Setting/Unsetting", context do
      %{user1: %{user: user1}, lobby_id: lobby_id} = context

      consul_state = Coordinator.call_consul(lobby_id, :get_consul_state)
      refute consul_state.quantum_mode?

      # Turn it on
      ChatLib.say(user1.id, "$quantum", lobby_id)

      consul_state = Coordinator.call_consul(lobby_id, :get_consul_state)
      assert consul_state.quantum_mode?

      # Give everything a moment to calm down, if we
      # immediately tell it to swap back we create some thrashing
      :timer.sleep(100)

      # Turn it off
      ChatLib.say(user1.id, "$quantum", lobby_id)

      consul_state = Coordinator.call_consul(lobby_id, :get_consul_state, 1000)
      refute consul_state.quantum_mode?

      # Turn it on with com count = 2
      ChatLib.say(user1.id, "$quantum coms=2", lobby_id)

      consul_state = Coordinator.call_consul(lobby_id, :get_consul_state)
      assert consul_state.quantum_mode?

      mo = Battle.get_modoptions(lobby_id)
      assert mo["game/quantum/coms"] == "2"
    end

    test "Balance does not disrupt", context do
      %{
        user1: %{user: user1},
        user2: %{user: user2},
        user3: %{user: user3},
        user4: %{user: user4},
        lobby_id: lobby_id
      } = context

      consul_state = Coordinator.call_consul(lobby_id, :get_consul_state)
      refute consul_state.quantum_mode?

      # We start by checking the ids don't already line up
      # we don't care who is which id, just that we have all 4 present
      ids =
        [
          ClientLib.get_client_by_id(user1.id).player_number,
          ClientLib.get_client_by_id(user2.id).player_number,
          ClientLib.get_client_by_id(user3.id).player_number,
          ClientLib.get_client_by_id(user4.id).player_number
        ]
        |> Enum.sort()

      assert ids == [1, 2, 3, 4]

      # Turn it on
      ChatLib.say(user1.id, "$quantum", lobby_id)

      consul_state = Coordinator.call_consul(lobby_id, :get_consul_state)
      assert consul_state.quantum_mode?

      # It's async so we need to give it a moment to perform the changes
      :timer.sleep(100)

      c1 = ClientLib.get_client_by_id(user1.id)
      assert c1.player_number == c1.team_number

      c2 = ClientLib.get_client_by_id(user2.id)
      assert c2.player_number == c2.team_number

      c3 = ClientLib.get_client_by_id(user3.id)
      assert c3.player_number == c3.team_number

      c4 = ClientLib.get_client_by_id(user4.id)
      assert c4.player_number == c4.team_number

      # Now we "apply" balance, this is done by SPADS (the server tells it what the
      # balance should be) so we will just fake it. The ConsulServer should
      # detect the changes and set them back again
      ClientLib.update_client(user1.id, %{player: true, player_number: 1, team_number: 1})
      ClientLib.update_client(user2.id, %{player: true, player_number: 2, team_number: 1})
      ClientLib.update_client(user3.id, %{player: true, player_number: 3, team_number: 2})
      ClientLib.update_client(user4.id, %{player: true, player_number: 4, team_number: 2})

      # Still async so give it a moment....
      Coordinator.send_consul(lobby_id, :tick)
      :timer.sleep(100)

      ids =
        [
          ClientLib.get_client_by_id(user1.id).player_number,
          ClientLib.get_client_by_id(user2.id).player_number,
          ClientLib.get_client_by_id(user3.id).player_number,
          ClientLib.get_client_by_id(user4.id).player_number
        ]
        |> Enum.sort()

      assert ids == [1, 1, 2, 2]
    end
  end
end
