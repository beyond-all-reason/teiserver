defmodule Teiserver.Coordinator.CoordinatorCommandsSyncTest do
  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.Account.UserLib
  alias Teiserver.BitParse
  alias Teiserver.CacheUser
  alias Teiserver.TeiserverTestLib

  use Teiserver.ServerCase, async: false

  import TeiserverTestLib,
    only: [
      auth_setup: 1,
      _send_raw: 2,
      _recv_until: 1,
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
      reply = _recv_until(socket)

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

      CacheUser.deprecated_recache_user(user.id)

      _send_raw(socket, "SAYPRIVATE coordinator $website\n")
      reply = _recv_until(socket)

      assert reply ==
               "SAYPRIVATE Coordinator $website\nSAIDPRIVATE Coordinator Your role contains one or more privileged roles, you will need to manually login to the site at https://localhost\n"

      Application.put_env(:teiserver, Teiserver, config)
    end

    test "$modme/$unmodme", %{socket: socket} = ctx do
      mod = TeiserverTestLib.new_user()
      Auth.add_roles(mod.id, ["Moderator"])
      %{socket: mod_socket} = TeiserverTestLib.auth_setup(ctx, mod)
      [_adduser, status] = TeiserverTestLib._recv_until(socket) |> String.split("\n", trim: true)
      ["CLIENTSTATUS", mod_name, str_status] = String.split(status)
      assert mod_name == mod.name
      BitParse.parse_bits(str_status, 7)
      [_bot_bit, mod_bit | _rest] = BitParse.parse_bits(str_status, 7)
      assert mod_bit == 1

      _send_raw(mod_socket, "SAYPRIVATE coordinator $unmodme\n")
      ["CLIENTSTATUS", mod_name, str_status] = _recv_until(socket) |> String.split()
      assert mod_name == mod.name
      [_bot_bit, mod_bit | _rest] = BitParse.parse_bits(str_status, 7)
      assert mod_bit == 0

      _send_raw(mod_socket, "SAYPRIVATE coordinator $modme\n")
      ["CLIENTSTATUS", mod_name, str_status] = _recv_until(socket) |> String.split()
      assert mod_name == mod.name
      [_bot_bit, mod_bit | _rest] = BitParse.parse_bits(str_status, 7)
      assert mod_bit == 1

      # only mods can $modme
      _recv_until(mod_socket)
      _send_raw(socket, "SAYPRIVATE coordinator $modme\n")
      assert _recv_until(mod_socket) == ""
    end
  end
end
