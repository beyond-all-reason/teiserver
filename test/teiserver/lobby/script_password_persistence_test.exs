defmodule Teiserver.Lobby.ScriptPasswordPersistenceTest do
  @moduledoc """
  Tests for issue #438: script_password must be stored in the LobbyServer
  so it can be recovered when clients (particularly SPADS) reconnect.
  """
  use Teiserver.ServerCase, async: false

  alias Teiserver.{Battle, Lobby}

  import Teiserver.TeiserverTestLib,
    only: [make_lobby: 0, new_user: 0]

  describe "LobbyServer script_password storage" do
    test "stores script_password when user is added to battle" do
      lobby_id = make_lobby()
      user = new_user()

      Lobby.add_user_to_battle(user.id, lobby_id, "test_password_123")
      :timer.sleep(100)

      passwords = Battle.get_lobby_script_passwords(lobby_id)
      assert passwords[user.id] == "test_password_123"
    end

    test "removes script_password when user leaves" do
      lobby_id = make_lobby()
      user = new_user()

      Lobby.add_user_to_battle(user.id, lobby_id, "removable_pw")
      :timer.sleep(100)

      passwords = Battle.get_lobby_script_passwords(lobby_id)
      assert passwords[user.id] == "removable_pw"

      Lobby.remove_user_from_battle(user.id, lobby_id)
      :timer.sleep(100)

      passwords = Battle.get_lobby_script_passwords(lobby_id)
      refute Map.has_key?(passwords, user.id)
    end

    test "stores distinct passwords for multiple users" do
      lobby_id = make_lobby()
      user1 = new_user()
      user2 = new_user()
      user3 = new_user()

      Lobby.add_user_to_battle(user1.id, lobby_id, "pw_alpha")
      Lobby.add_user_to_battle(user2.id, lobby_id, "pw_beta")
      Lobby.add_user_to_battle(user3.id, lobby_id, "pw_gamma")
      :timer.sleep(100)

      passwords = Battle.get_lobby_script_passwords(lobby_id)
      assert passwords[user1.id] == "pw_alpha"
      assert passwords[user2.id] == "pw_beta"
      assert passwords[user3.id] == "pw_gamma"
      assert map_size(passwords) == 3
    end

    test "get_lobby_script_passwords returns nil for non-existent lobby" do
      result = Battle.get_lobby_script_passwords(999_999_999)
      assert result == nil
    end

    test "password is updated if user rejoins with different password" do
      lobby_id = make_lobby()
      user = new_user()

      Lobby.add_user_to_battle(user.id, lobby_id, "first_pw")
      :timer.sleep(100)

      passwords = Battle.get_lobby_script_passwords(lobby_id)
      assert passwords[user.id] == "first_pw"

      # Remove and re-add with different password
      Lobby.remove_user_from_battle(user.id, lobby_id)
      :timer.sleep(50)
      Lobby.add_user_to_battle(user.id, lobby_id, "second_pw")
      :timer.sleep(100)

      passwords = Battle.get_lobby_script_passwords(lobby_id)
      assert passwords[user.id] == "second_pw"
    end

    test "add_user_to_battle/2 auto-generates a script_password that is stored" do
      lobby_id = make_lobby()
      user = new_user()

      # The 2-arg version generates a random password
      Lobby.add_user_to_battle(user.id, lobby_id)
      :timer.sleep(100)

      passwords = Battle.get_lobby_script_passwords(lobby_id)
      assert Map.has_key?(passwords, user.id)
      assert is_binary(passwords[user.id])
      assert String.length(passwords[user.id]) > 0
    end

    test "script_passwords start empty for new lobby" do
      lobby_id = make_lobby()

      passwords = Battle.get_lobby_script_passwords(lobby_id)
      assert passwords == %{}
    end
  end
end
