defmodule Teiserver.Lobby.ScriptPasswordPersistenceTest do
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
      assert Battle.get_lobby_script_passwords(lobby_id)[user.id] == "removable_pw"

      Lobby.remove_user_from_battle(user.id, lobby_id)
      :timer.sleep(100)
      refute Map.has_key?(Battle.get_lobby_script_passwords(lobby_id), user.id)
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

    test "returns nil for non-existent lobby" do
      assert Battle.get_lobby_script_passwords(999_999_999) == nil
    end

    test "password is updated on rejoin" do
      lobby_id = make_lobby()
      user = new_user()

      Lobby.add_user_to_battle(user.id, lobby_id, "first_pw")
      :timer.sleep(100)
      assert Battle.get_lobby_script_passwords(lobby_id)[user.id] == "first_pw"

      Lobby.remove_user_from_battle(user.id, lobby_id)
      :timer.sleep(50)
      Lobby.add_user_to_battle(user.id, lobby_id, "second_pw")
      :timer.sleep(100)
      assert Battle.get_lobby_script_passwords(lobby_id)[user.id] == "second_pw"
    end

    test "add_user_to_battle/2 auto-generates a stored password" do
      lobby_id = make_lobby()
      user = new_user()

      Lobby.add_user_to_battle(user.id, lobby_id)
      :timer.sleep(100)

      password = Battle.get_lobby_script_passwords(lobby_id)[user.id]
      assert is_binary(password) and byte_size(password) > 0
    end

    test "starts empty for new lobby" do
      lobby_id = make_lobby()
      assert Battle.get_lobby_script_passwords(lobby_id) == %{}
    end
  end
end
