defmodule Teiserver.Autohost.AutohostTest do
  use Teiserver.DataCase, async: false
  import Teiserver.Support.Polling, only: [poll_until: 2, poll_until_nil: 1]

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
    Autohost.Registry.register(%{id: id, max_battles: max, current_battles: current})
  end

  describe "message parser" do
    alias Teiserver.Autohost.TachyonHandler, as: TH

    test "start" do
      msg = %{
        "commandId" => "autohost/update",
        "data" => %{
          "battleId" => "d9eff7cb-ab31-4070-8bd8-376acf9c5095",
          "time" => 1_748_191_579_196_000,
          "update" => %{"type" => "start"}
        },
        "messageId" => "bb732bd7-c549-4f26-b29b-e1b8d2c99c96",
        "type" => "event"
      }

      expected = %{
        battle_id: "d9eff7cb-ab31-4070-8bd8-376acf9c5095",
        time: DateTime.from_unix!(1_748_191_579_196_000, :microsecond),
        update: :start
      }

      assert TH.parse_update_event(msg["data"]) == {:ok, expected}
    end

    test "finished" do
      msg = %{
        "commandId" => "autohost/update",
        "data" => %{
          "battleId" => "d9eff7cb-ab31-4070-8bd8-376acf9c5095",
          "time" => 1_748_191_573_075_000,
          "update" => %{"type" => "finished", "userId" => "43", "winningAllyTeams" => [1]}
        },
        "messageId" => "46dc384f-1ffe-4cac-8a77-1fd1927f0437",
        "type" => "event"
      }

      expected = %{
        battle_id: "d9eff7cb-ab31-4070-8bd8-376acf9c5095",
        time: DateTime.from_unix!(1_748_191_573_075_000, :microsecond),
        update: {:finished, %{user_id: 43, winning_ally_teams: [1]}}
      }

      assert TH.parse_update_event(msg["data"]) == {:ok, expected}
    end

    test "player chat broadcast" do
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
        "messageId" => "46dc384f-1ffe-4cac-8a77-1fd1927f0437",
        "type" => "event"
      }

      expected = %{
        battle_id: "d9eff7cb-ab31-4070-8bd8-376acf9c5095",
        time: DateTime.from_unix!(1_748_191_573_075_000, :microsecond),
        update: {:player_chat_broadcast, %{destination: :all, message: "blah", user_id: 5}}
      }

      assert TH.parse_update_event(msg["data"]) == {:ok, expected}
    end

    test "player chat dm" do
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
        "messageId" => "46dc384f-1ffe-4cac-8a77-1fd1927f0437",
        "type" => "event"
      }

      expected = %{
        battle_id: "d9eff7cb-ab31-4070-8bd8-376acf9c5095",
        time: DateTime.from_unix!(1_748_191_573_075_000, :microsecond),
        update: {:player_chat_dm, %{to_user_id: 42, message: "blah", user_id: 5}}
      }

      assert TH.parse_update_event(msg["data"]) == {:ok, expected}
    end

    test "player chat dm, invalid target" do
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
        "messageId" => "46dc384f-1ffe-4cac-8a77-1fd1927f0437",
        "type" => "event"
      }

      assert {:error, _} = TH.parse_update_event(msg["data"])
    end
  end
end
