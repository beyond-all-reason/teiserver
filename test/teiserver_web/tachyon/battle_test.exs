defmodule TeiserverWeb.Tachyon.BattleTest do
  use TeiserverWeb.ConnCase
  alias Teiserver.Support.{Polling, Tachyon}
  alias Teiserver.OAuthFixtures
  alias Teiserver.TachyonBattle

  defp setup_app(_context) do
    owner = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})

    app =
      OAuthFixtures.app_attrs(owner.id)
      |> Map.put(:uid, UUID.uuid4())
      |> OAuthFixtures.create_app()

    {:ok, app: app}
  end

  setup [:setup_app, {Tachyon, :setup_autohost}]

  # this test is a bit meh because it uses a fairly high level API (the tachyon ws protocol)
  # but tests some internals of the Battle process
  # Not sure about a better way though
  test "battle timeout", %{autohost: autohost, autohost_client: autohost_client} do
    Polling.poll_until_some(&Teiserver.Autohost.find_autohost/0)

    assert {:ok, pid} =
             TachyonBattle.Battle.start(%{
               battle_id: "whatever",
               autohost_id: autohost.id,
               autohost_timeout: 1
             })

    Tachyon.disconnect!(autohost_client)
    Polling.poll_until(&Teiserver.Autohost.find_autohost/0, &is_nil/1)
    Polling.poll_until(fn -> Process.alive?(pid) end, &(&1 == false))
  end

  test "stop battle", %{autohost: autohost, autohost_client: autohost_client} do
    Polling.poll_until_some(&Teiserver.Autohost.find_autohost/0)
    battle_id = "whatever"

    assert {:ok, _pid} =
             TachyonBattle.Battle.start(%{
               battle_id: battle_id,
               autohost_id: autohost.id,
               autohost_timeout: 1
             })

    ev = %{
      battleId: battle_id,
      time: 1_705_432_698_000_000,
      update: %{
        type: "player_chat",
        userId: "123",
        message: "!stop",
        destination: "all"
      }
    }

    Tachyon.autohost_send_update_event(autohost_client, ev)

    assert %{"commandId" => "autohost/kill", "data" => %{"battleId" => ^battle_id}} =
             Tachyon.recv_message!(autohost_client)
  end
end
