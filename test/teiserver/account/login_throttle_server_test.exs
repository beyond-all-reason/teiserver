defmodule Teiserver.Account.LoginThrottleServerTest do
  @moduledoc false

  use Central.DataCase, async: true
  alias Central.Config
  alias Teiserver.Account
  alias Teiserver.Account.LoginThrottleServer
  import Teiserver.TeiserverTestLib, only: [
    new_user: 0
  ]

  test "throttle test" do
    Teiserver.TeiserverConfigs.teiserver_configs()

    # Wait for the queue server to have started up
    :timer.sleep(1000)

    bot = new_user()
    # Account.update_cache_user(bot.id, %{roles: ["Bot"]})
    # moderator = new_user() |> Account.update_cache_user(%{roles: ["Moderator"]})
    # contributor = new_user() |> Account.update_cache_user(%{roles: ["Contributor"]})
    # standard = new_user() |> Account.update_cache_user(%{roles: ["Standard"]})
    # toxic = new_user() |> Account.update_cache_user(%{behaviour_score: 1})

    Config.update_site_config("system.User limit", 0)

    r = LoginThrottleServer.attempt_login(bot.id)
    assert r == :login
  end
end
