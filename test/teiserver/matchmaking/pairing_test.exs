defmodule Teiserver.Matchmaking.PairingTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.Matchmaking.PairingRoom

  defp queue_attrs() do
    %{
      name: UUID.uuid4(),
      team_size: 1,
      team_count: 2,
      ranked: true
    }
  end

  defp make_member() do
    %{
      id: UUID.uuid4(),
      player_ids: [:rand.uniform(999_999_999)],
      rating: %{},
      avoid: [],
      joined_at: DateTime.utc_now(),
      search_distance: 1,
      increase_distance_after: 10
    }
  end

  describe "ready" do
    test "must be part of the room" do
      [m1, m2] = [make_member(), make_member()]
      teams = [[m1], [m2]]
      {:ok, pid} = PairingRoom.start("queue_id", queue_attrs(), teams, 20_000)

      # credo:disable-for-lines:2 Credo.Check.Readability.LargeNumbers
      assert {:error, :no_match} =
               PairingRoom.ready(pid, %{user_id: -81234, name: "irrelevant", password: "pass"})
    end

    test "can join" do
      [m1, m2] = [make_member(), make_member()]
      teams = [[m1], [m2]]
      {:ok, pid} = PairingRoom.start("queue_id", queue_attrs(), teams, 20_000)

      assert {:error, :no_match} =
               PairingRoom.ready(pid, %{user_id: m1.id, name: "irrelevant", password: "pass"})
    end
  end
end
