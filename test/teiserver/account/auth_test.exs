defmodule Teiserver.Account.AuthTest do
  alias Teiserver.Account
  alias Teiserver.Account.AuthLib
  alias Teiserver.AccountFixtures

  use Teiserver.DataCase, async: false

  setup do
    config = Application.get_env(:teiserver, Teiserver)
    new_config = Keyword.put(config, :require_mfa_for_privileged_roles, true)
    Application.put_env(:teiserver, Teiserver, new_config)

    user = AccountFixtures.user_fixture(%{roles: ["Server"], permissions: ["Server"]})

    on_exit(fn ->
      Application.put_env(:teiserver, Teiserver, config)
    end)

    %{user: user}
  end

  describe "MFA functions" do
    test "allow?/2 - no MFA present", %{user: user} do
      refute AuthLib.has_active_mfa?(user.id)
      refute AuthLib.allow?(user, "Server")
    end

    test "allow?/2 - bots are exempt" do
      user =
        AccountFixtures.user_fixture(%{roles: ["Server", "Bot"], permissions: ["Server", "Bot"]})

      refute AuthLib.has_active_mfa?(user.id)
      assert AuthLib.allow?(user, "Server")
    end

    test "allow?/2 - MFA present", %{user: user} do
      Account.set_secret(user.id, "secret")
      assert AuthLib.has_active_mfa?(user.id)
      assert AuthLib.allow?(user, "Server")
    end
  end
end
