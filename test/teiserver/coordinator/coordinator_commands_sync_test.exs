defmodule Teiserver.Coordinator.CoordinatorCommandsSyncTest do
  alias Teiserver.Account
  alias Teiserver.Account.UserLib
  alias Teiserver.CacheUser

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
  end
end
