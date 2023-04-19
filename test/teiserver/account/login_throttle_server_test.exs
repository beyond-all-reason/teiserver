defmodule Teiserver.Account.LoginThrottleServerTest do
  @moduledoc false

  use Central.DataCase, async: false
  alias Central.Config
  alias Teiserver.Account
  alias Teiserver.Account.LoginThrottleServer
  import Teiserver.TeiserverTestLib, only: [
    new_user: 0
  ]

  test "throttle test" do
    Teiserver.TeiserverConfigs.teiserver_configs()
    pid = LoginThrottleServer.get_login_throttle_server_pid()
    Config.update_site_config("system.User limit", 10)

    send(pid, %{channel: "teiserver_telemetry", event: :data, data: %{
      client: %{
        total: 10
      }
    }})

    bot = new_user()
    Account.update_cache_user(bot.id, %{roles: ["Bot"]})

    moderator = new_user()
    Account.update_cache_user(moderator.id, %{roles: ["Moderator"]})

    contributor = new_user()
    Account.update_cache_user(contributor.id, %{roles: ["Contributor"]})

    vip = new_user()
    Account.update_cache_user(vip.id, %{roles: ["VIP"]})

    standard = new_user()
    Account.update_cache_user(standard.id, %{roles: ["Standard"]})

    toxic = new_user()
    Account.update_cache_user(toxic.id, %{behaviour_score: 1})

    # Bots should get in regardless of capacity
    r = LoginThrottleServer.attempt_login(bot.id)
    assert r == true

    # Moderators have to wait in the queue
    r = LoginThrottleServer.attempt_login(moderator.id)
    assert r == false

    # Now do the same for the other users
    r = LoginThrottleServer.attempt_login(contributor.id)
    assert r == false

    r = LoginThrottleServer.attempt_login(vip.id)
    assert r == false

    r = LoginThrottleServer.attempt_login(standard.id)
    assert r == false

    r = LoginThrottleServer.attempt_login(toxic.id)
    assert r == false



    state = :sys.get_state(pid)
    assert state.queues.moderator == [moderator.id]
    refute state.queues.contributor == [contributor.id]
    refute state.queues.vip == [vip.id]
    refute state.queues.standard == [standard.id]
    refute state.queues.toxic == [toxic.id]
  end
end
