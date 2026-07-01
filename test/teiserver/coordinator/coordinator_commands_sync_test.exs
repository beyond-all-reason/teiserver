defmodule Teiserver.Coordinator.CoordinatorCommandsSyncTest do
  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.Account.UserLib
  alias Teiserver.CacheUser

  use Teiserver.ServerCase, async: false

  import TeiserverTestLib,
    only: [
      auth_setup: 1,
      auth_setup: 2,
      new_user: 1,
      _recv_until: 1,
      _send_raw: 2,
      _recv_raw: 1,
      start_spring_server: 1
    ]

  setup :start_spring_server

  setup(context) do
    TeiserverTestLib.start_coordinator!()
    %{socket: socket, user: user} = auth_setup(context)
    {:ok, socket: socket, user: user}
  end

  describe "commands" do
    test "$website - okay", %{socket: socket} do
      _send_raw(socket, "SAYPRIVATE Coordinator $website\n")
      reply = _recv_raw(socket)

      assert reply =~
               "SAYPRIVATE Coordinator $website\nSAIDPRIVATE Coordinator Your one-time login link is https://localhost/one_time_login"
    end

    test "$website - mfa role", %{socket: socket, user: user} do
      # This only works if MFA is required, we will enable it for this test
      config = Application.get_env(:teiserver, Teiserver)
      new_config = Keyword.put(config, :require_mfa_for_privileged_roles, true)
      Application.put_env(:teiserver, Teiserver, new_config)

      user.id
      |> Account.get_user!()
      |> UserLib.script_update_user(%{roles: ["Admin"]})

      CacheUser.recache_user(user.id)

      _send_raw(socket, "SAYPRIVATE coordinator $website\n")
      reply = _recv_raw(socket)

      assert reply ==
               "SAYPRIVATE Coordinator $website\nSAIDPRIVATE Coordinator Your role contains one or more privileged roles, you will need to manually login to the site at https://localhost\n"

      Application.put_env(:teiserver, Teiserver, config)
    end

    test "modme - not moderator", %{socket: socket, user: user} do
      client = Account.get_client_by_id(user.id)
      refute client.moderator
      refute client.show_moderator

      _send_raw(socket, "SAYPRIVATE coordinator $modme\n")
      :timer.sleep(100)

      client = Account.get_client_by_id(user.id)
      refute client.moderator
      refute client.show_moderator
    end

    test "modme/unmodme - as moderator", context do
      user_watcher = new_user("user_watcher")
      %{socket: user_watcher_socket} = auth_setup(context, user_watcher)
      bot_watcher = new_user("bot_watcher")
      %{socket: bot_watcher_socket} = auth_setup(context, bot_watcher)
      {:ok, _} = Auth.add_roles(bot_watcher.id, ["Bot"])

      std_user = new_user("std_watcher")
      %{socket: std_socket} = auth_setup(context, std_user)
      mod_user = new_user("mod_user")
      %{socket: mod_socket} = auth_setup(context, mod_user)
      {:ok, _} = Auth.add_roles(mod_user.id, ["Moderator"])

      lines1 = _recv_until(user_watcher_socket)
      lines2 = _recv_until(bot_watcher_socket)

      _recv_until(mod_socket)

      IO.puts "MODME"
      _send_raw(std_socket, "SAYPRIVATE coordinator $modme\n")
      _send_raw(mod_socket, "SAYPRIVATE coordinator $modme\n")

      lines3 = _recv_until(user_watcher_socket)
      lines4 = _recv_until(bot_watcher_socket)

      lines5 = _recv_until(mod_socket)

      IO.puts "lines1"
      IO.puts lines1
      IO.puts ""
      IO.puts "lines2"
      IO.puts lines2
      IO.puts ""
      IO.puts "lines3"
      IO.puts lines3
      IO.puts ""
      IO.puts "lines4"
      IO.puts lines4
      IO.puts ""

      IO.puts ""
      IO.puts lines5
      IO.puts ""
    end
  end
end
