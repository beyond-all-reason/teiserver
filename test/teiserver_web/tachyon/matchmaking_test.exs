defmodule Teiserver.Matchmaking.MatchmakingTest do
  use TeiserverWeb.ConnCase
  alias Teiserver.Support.Tachyon
  alias WebsocketSyncClient, as: WSC

  # redefinition because ExUnit < 1.15 doesn't support passing setup
  # definition as {Tachyon, :setup_client}
  defp setup_client(_context), do: Tachyon.setup_client()

  describe "list" do
    setup :setup_client

    test "works", %{client: client} do
      resp = Tachyon.list_queues!(client)

      # convert into a set since the order must not impact test result
      expected_playlists =
        MapSet.new([
          %{
            "id" => "1v1",
            "name" => "Duel",
            "numOfTeams" => 2,
            "teamSize" => 1,
            "ranked" => true
          }
        ])

      assert MapSet.new(resp["data"]["playlists"]) == expected_playlists
    end
  end
end
