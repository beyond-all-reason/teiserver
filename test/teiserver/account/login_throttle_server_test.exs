defmodule Teiserver.Account.LoginThrottleServerTest do
  @moduledoc false

  use Teiserver.DataCase, async: false
  alias Teiserver.Config
  alias Teiserver.Account
  alias Teiserver.Account.LoginThrottleServer
  alias Teiserver.Common.PubsubListener

  import Teiserver.TeiserverTestLib,
    only: [
      new_user: 0
    ]

  @sleep_time 500

  # For reasons unknown this test often results in the wrong number of people
  # being released at various stages. I have no idea why (but it does work in prod)
  test "multiple queues" do
    pid = LoginThrottleServer.get_login_throttle_server_pid()
    LoginThrottleServer.set_value(:releases_per_tick, 1)
    # LoginThrottleServer.set_value(:set_tick_period, 60_000)
    send(pid, :disable_tick_timer)

    Teiserver.TeiserverConfigs.teiserver_configs()
    Config.update_site_config("system.User limit", 10)

    throttle_listener = PubsubListener.new_listener(["teiserver_liveview_login_throttle"])

    bot = new_user()
    Account.update_cache_user(bot.id, %{roles: ["Bot"]})
    bot_listener = PubsubListener.new_listener([])

    moderator = new_user()
    Account.update_cache_user(moderator.id, %{roles: ["Moderator"]})
    moderator_listener = PubsubListener.new_listener([])

    contributor = new_user()
    Account.update_cache_user(contributor.id, %{roles: ["Contributor"]})
    contributor_listener = PubsubListener.new_listener([])

    vip = new_user()
    Account.update_cache_user(vip.id, %{roles: ["VIP"]})
    vip_listener = PubsubListener.new_listener([])

    standard = new_user()
    Account.update_cache_user(standard.id, %{roles: ["Standard"]})
    standard_listener = PubsubListener.new_listener([])

    toxic = new_user()
    Account.update_cache_user(toxic.id, %{behaviour_score: 1})
    toxic_listener = PubsubListener.new_listener([])

    assert PubsubListener.get(throttle_listener) == []

    send(pid, %{
      channel: "teiserver_telemetry",
      event: :data,
      data: %{
        client: %{
          total: 10
        }
      }
    })

    send(pid, :tick)
    :timer.sleep(@sleep_time)

    # Bots should get in regardless of capacity, no messages for the listener
    r = LoginThrottleServer.attempt_login(bot_listener, bot.id)
    assert r == true
    assert PubsubListener.get(bot_listener) == []

    # Moderators have to wait in the queue
    r = LoginThrottleServer.attempt_login(moderator_listener, moderator.id)
    assert r == false
    assert PubsubListener.get(moderator_listener) == []

    # Now do the same for the other users
    r = LoginThrottleServer.attempt_login(contributor_listener, contributor.id)
    assert r == false
    assert PubsubListener.get(contributor_listener) == []

    r = LoginThrottleServer.attempt_login(vip_listener, vip.id)
    assert r == false
    assert PubsubListener.get(vip_listener) == []

    r = LoginThrottleServer.attempt_login(standard_listener, standard.id)
    assert r == false
    assert PubsubListener.get(standard_listener) == []

    r = LoginThrottleServer.attempt_login(toxic_listener, toxic.id)
    assert r == false
    assert PubsubListener.get(toxic_listener) == []

    state = :sys.get_state(pid)
    assert state.queues.moderator == [moderator.id]
    assert state.queues.contributor == [contributor.id]
    assert state.queues.vip == [vip.id]
    assert state.queues.standard == [standard.id]
    assert state.queues.toxic == [toxic.id]

    assert Enum.count(state.recent_logins) == 1

    # We let one through (the bot) even though we were at capacity
    assert state.remaining_capacity == -1

    # Now we alter the capacity and see what happens
    send(pid, %{
      channel: "teiserver_telemetry",
      event: :data,
      data: %{
        client: %{
          total: 9
        }
      }
    })

    send(pid, :tick)

    # Give it a chance to dequeue
    :timer.sleep(@sleep_time)

    assert PubsubListener.get(moderator_listener) == [{:login_accepted, moderator.id}]
    assert PubsubListener.get(contributor_listener) == []
    assert PubsubListener.get(vip_listener) == []
    assert PubsubListener.get(standard_listener) == []
    assert PubsubListener.get(toxic_listener) == []

    state = :sys.get_state(pid)
    assert state.queues.moderator == []
    assert state.queues.contributor == [contributor.id]
    assert state.queues.vip == [vip.id]
    assert state.queues.standard == [standard.id]
    assert state.queues.toxic == [toxic.id]

    assert Enum.count(state.recent_logins) == 2

    :timer.sleep(@sleep_time)

    # Ensure no more updates in the meantime, should only happen when we tell it to tick
    assert PubsubListener.get(moderator_listener) == []
    assert PubsubListener.get(contributor_listener) == []
    assert PubsubListener.get(vip_listener) == []
    assert PubsubListener.get(standard_listener) == []
    assert PubsubListener.get(toxic_listener) == []

    # Flush the throttle messages
    PubsubListener.get(throttle_listener)

    # Now approve the rest of them
    # the toxic one will have to wait a bit longer though
    send(pid, %{
      channel: "teiserver_telemetry",
      event: :data,
      data: %{
        client: %{
          total: 4
        }
      }
    })

    state = :sys.get_state(pid)
    assert state.remaining_capacity == 6

    throttle_messages = PubsubListener.get(throttle_listener)
    assert throttle_messages == [
      %{
        channel: "teiserver_liveview_login_throttle",
        event: :updated_capacity,
        remaining_capacity: 6
      }
    ]

    # Dequeue the next more
    send(pid, :tick)
    :timer.sleep(@sleep_time)

    assert PubsubListener.get(moderator_listener) == []
    assert PubsubListener.get(contributor_listener) == [{:login_accepted, contributor.id}]
    assert PubsubListener.get(vip_listener) == []
    assert PubsubListener.get(standard_listener) == []
    assert PubsubListener.get(toxic_listener) == []

    send(pid, :tick)

    # Give it a chance to dequeue
    :timer.sleep(@sleep_time)

    assert PubsubListener.get(moderator_listener) == []
    assert PubsubListener.get(contributor_listener) == [{:login_accepted, contributor.id}]
    assert PubsubListener.get(vip_listener) == [{:login_accepted, vip.id}]
    assert PubsubListener.get(standard_listener) == [{:login_accepted, standard.id}]
    assert PubsubListener.get(toxic_listener) == []

    state = :sys.get_state(pid)
    assert state.queues.moderator == []
    assert state.queues.contributor == []
    assert state.queues.vip == []
    assert state.queues.standard == []
    assert state.queues.toxic == [toxic.id]

    assert Enum.count(state.recent_logins) == 5
  end
end
