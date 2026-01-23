defmodule Teiserver.Autohost.AutohostTest do
  use Teiserver.DataCase, async: false
  import Teiserver.Support.Polling, only: [poll_until: 2, poll_until_nil: 1]

  alias Teiserver.BotFixtures
  alias Teiserver.Autohost

  @moduletag :tachyon

  describe "find autohost" do
    test "no autohost available" do
      assert nil == Autohost.find_autohost()
    end

    test "one available autohost" do
      register_autohost(123, 10, 1)
      poll_until(&Autohost.find_autohost/0, &(&1 == 123))
    end

    test "no capacity" do
      register_autohost(123, 0, 2)
      poll_until_nil(&Autohost.find_autohost/0)
    end

    test "look at all autohosts" do
      register_autohost(123, 0, 10)
      register_autohost(456, 10, 2)
      poll_until(&Autohost.find_autohost/0, &(&1 == 456))
    end
  end

  defp register_autohost(id, max, current) do
    Autohost.SessionRegistry.register(%{id: id, max_battles: max, current_battles: current})
  end

  describe "autohost state" do
    test "postpone calls until autohost updates capacity" do
      autohost = BotFixtures.create_bot()

      sess_pid =
        Autohost.Session.child_spec({autohost, self()})
        |> ExUnit.Callbacks.start_link_supervised!()

      assert_receive({:call_client, "autohost/subscribeUpdates", _, ref})
      send(ref, {ref, %{"status" => "success"}})

      Task.async(fn ->
        Autohost.start_battle(autohost.id, "battle_id", BotFixtures.start_script())
      end)

      refute_receive {:start_battle, "battle_id", _}
      # need to update capacity first, only then the autohost is considered fully online
      Autohost.Session.update_capacity(sess_pid, 10, 0)

      assert_receive {:start_battle, "battle_id", _}
    end

    test "default subscribe messages from now" do
      ctx = setup_autohost()
      ctx = Map.merge(ctx, setup_battle(ctx.autohost, ctx.pid))
      sub_start = Autohost.Session.inspect_subscription_start(ctx.autohost.id)

      assert_in_delta DateTime.to_unix(sub_start, :millisecond),
                      DateTime.to_unix(DateTime.utc_now(), :millisecond),
                      5
    end

    test "track update messages" do
      ctx = setup_autohost()
      ctx = Map.merge(ctx, setup_battle(ctx.autohost, ctx.pid))
      t0 = ~U[2026-01-23 12:34:56.00Z]
      event = %{message_id: "123", battle_id: ctx.battle_id, time: t0}
      Autohost.Session.handle_update_event(ctx.pid, event)

      sub_start = Autohost.Session.inspect_subscription_start(ctx.autohost.id)
      assert sub_start == DateTime.shift(t0, microsecond: {-1, 6})
    end

    test "track updates with ack" do
      ctx = setup_autohost()
      ctx = Map.merge(ctx, setup_battle(ctx.autohost, ctx.pid))
      t0 = ~U[2026-01-23 12:34:56.00Z]
      event = %{message_id: "123", battle_id: ctx.battle_id, time: t0}
      Autohost.Session.handle_update_event(ctx.pid, event)
      Autohost.Session.ack_update_event(ctx.pid, ctx.battle_id, t0)

      sub_start = Autohost.Session.inspect_subscription_start(ctx.autohost.id)
      assert sub_start == t0
    end

    test "track multiple update message same battle" do
      ctx = setup_autohost()
      %{battle_id: battle_id} = setup_battle(ctx.autohost, ctx.pid)

      t0 = ~U[2026-01-23 03:00:00.00Z]
      event0 = %{message_id: "123", battle_id: battle_id, time: t0}

      t1 = ~U[2026-01-23 12:34:56.00Z]
      event1 = %{message_id: "123", battle_id: battle_id, time: t1}

      Autohost.Session.handle_update_event(ctx.pid, event0)
      Autohost.Session.handle_update_event(ctx.pid, event1)

      sub_start = Autohost.Session.inspect_subscription_start(ctx.autohost.id)
      assert sub_start == DateTime.shift(t0, microsecond: {-1, 6})
    end

    test "track update message across multiple battles" do
      ctx = setup_autohost()
      %{battle_id: bid1} = setup_battle(ctx.autohost, ctx.pid)
      %{battle_id: bid2} = setup_battle(ctx.autohost, ctx.pid)

      t0 = ~U[2026-01-23 03:00:00.00Z]
      event0 = %{message_id: "123", battle_id: bid1, time: t0}

      t1 = ~U[2026-01-23 12:34:56.00Z]
      event1 = %{message_id: "123", battle_id: bid2, time: t1}

      Autohost.Session.handle_update_event(ctx.pid, event0)
      Autohost.Session.handle_update_event(ctx.pid, event1)

      sub_start = Autohost.Session.inspect_subscription_start(ctx.autohost.id)
      assert sub_start == DateTime.shift(t0, microsecond: {-1, 6})
    end
  end

  defp setup_autohost() do
    autohost = BotFixtures.create_bot()

    sess_pid =
      Autohost.Session.child_spec({autohost, self()})
      |> ExUnit.Callbacks.start_link_supervised!()

    assert_receive({:call_client, "autohost/subscribeUpdates", _, ref})
    send(ref, {ref, %{"status" => "success"}})
    Autohost.Session.update_capacity(sess_pid, 10, 0)
    %{autohost: autohost, pid: sess_pid}
  end

  defp setup_battle(autohost, pid) do
    battle_id = to_string(UUID.uuid4())

    Task.async(fn ->
      Autohost.start_battle(autohost.id, battle_id, BotFixtures.start_script())
    end)

    assert_receive {:start_battle, ^battle_id, _}
    Autohost.Session.reply_start_battle(pid, battle_id, {:ok, %{ips: ["1.2.3.4"], port: 1234}})
    %{battle_id: battle_id}
  end

  describe "message parser" do
    alias Teiserver.Autohost.TachyonHandler, as: TH

    test "start" do
      msg_id = "bb732bd7-c549-4f26-b29b-e1b8d2c99c96"

      msg = %{
        "commandId" => "autohost/update",
        "data" => %{
          "battleId" => "d9eff7cb-ab31-4070-8bd8-376acf9c5095",
          "time" => 1_748_191_579_196_000,
          "update" => %{"type" => "start"}
        },
        "messageId" => msg_id,
        "type" => "event"
      }

      expected = %{
        message_id: msg_id,
        battle_id: "d9eff7cb-ab31-4070-8bd8-376acf9c5095",
        time: DateTime.from_unix!(1_748_191_579_196_000, :microsecond),
        update: :start
      }

      assert TH.parse_update_event(msg_id, msg["data"]) == {:ok, expected}
    end

    test "finished" do
      msg_id = "46dc384f-1ffe-4cac-8a77-1fd1927f0437"

      msg = %{
        "commandId" => "autohost/update",
        "data" => %{
          "battleId" => "d9eff7cb-ab31-4070-8bd8-376acf9c5095",
          "time" => 1_748_191_573_075_000,
          "update" => %{"type" => "finished", "userId" => "43", "winningAllyTeams" => [1]}
        },
        "messageId" => msg_id,
        "type" => "event"
      }

      expected = %{
        message_id: msg_id,
        battle_id: "d9eff7cb-ab31-4070-8bd8-376acf9c5095",
        time: DateTime.from_unix!(1_748_191_573_075_000, :microsecond),
        update: {:finished, %{user_id: 43, winning_ally_teams: [1]}}
      }

      assert TH.parse_update_event(msg_id, msg["data"]) == {:ok, expected}
    end

    test "player chat broadcast" do
      msg_id = "46dc384f-1ffe-4cac-8a77-1fd1927f0437"

      msg = %{
        "commandId" => "autohost/update",
        "data" => %{
          "battleId" => "d9eff7cb-ab31-4070-8bd8-376acf9c5095",
          "time" => 1_748_191_573_075_000,
          "update" => %{
            "destination" => "all",
            "message" => "blah",
            "type" => "player_chat",
            "userId" => "5"
          }
        },
        "messageId" => msg_id,
        "type" => "event"
      }

      expected = %{
        message_id: msg_id,
        battle_id: "d9eff7cb-ab31-4070-8bd8-376acf9c5095",
        time: DateTime.from_unix!(1_748_191_573_075_000, :microsecond),
        update: {:player_chat_broadcast, %{destination: :all, message: "blah", user_id: 5}}
      }

      assert TH.parse_update_event(msg_id, msg["data"]) == {:ok, expected}
    end

    test "player chat dm" do
      msg_id = "46dc384f-1ffe-4cac-8a77-1fd1927f0437"

      msg = %{
        "commandId" => "autohost/update",
        "data" => %{
          "battleId" => "d9eff7cb-ab31-4070-8bd8-376acf9c5095",
          "time" => 1_748_191_573_075_000,
          "update" => %{
            "destination" => "player",
            "message" => "blah",
            "type" => "player_chat",
            "userId" => "5",
            "toUserId" => "42"
          }
        },
        "messageId" => msg_id,
        "type" => "event"
      }

      expected = %{
        message_id: msg_id,
        battle_id: "d9eff7cb-ab31-4070-8bd8-376acf9c5095",
        time: DateTime.from_unix!(1_748_191_573_075_000, :microsecond),
        update: {:player_chat_dm, %{to_user_id: 42, message: "blah", user_id: 5}}
      }

      assert TH.parse_update_event(msg_id, msg["data"]) == {:ok, expected}
    end

    test "player chat dm, invalid target" do
      msg_id = "46dc384f-1ffe-4cac-8a77-1fd1927f0437"

      msg = %{
        "commandId" => "autohost/update",
        "data" => %{
          "battleId" => "d9eff7cb-ab31-4070-8bd8-376acf9c5095",
          "time" => 1_748_191_573_075_000,
          "update" => %{
            "destination" => "player",
            "message" => "blah",
            "type" => "player_chat",
            "userId" => "5",
            "toUserId" => "not-a-number"
          }
        },
        "messageId" => msg_id,
        "type" => "event"
      }

      assert {:error, _} = TH.parse_update_event(msg_id, msg["data"])
    end
  end
end
