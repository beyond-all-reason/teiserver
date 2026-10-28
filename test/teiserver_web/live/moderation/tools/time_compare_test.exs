defmodule TeiserverWeb.Moderation.ToolsLive.TimeCompare do
  alias Teiserver.AccountFixtures
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Logging

  use TeiserverWeb.ConnCase, async: true

  describe "access control" do
    test "cannot access list page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/tools/time_compare")
      assert path == ~p"/login"
    end

    test "cannot access list page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Overwatch"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/moderation/tools/time_compare")
      assert path == ~p"/"
    end

    test "can access list page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/moderation/tools/time_compare")

      assert has_element?(live, "#time_compare-form")
      assert has_element?(live, "#no-results-alert")
    end
  end

  describe "report execution" do
    setup [:auth]

    test "report executes for 3 users - no results", %{conn: conn} do
      user1 = AccountFixtures.user_fixture()
      user2 = AccountFixtures.user_fixture()
      user3 = AccountFixtures.user_fixture()

      {:ok, live, _html} =
        live(
          conn,
          ~p"/moderation/tools/time_compare?user1=#{user1.id}&user2=#{user2.id}&user3=#{user3.id}"
        )

      assert has_element?(live, "#time_compare-form")
      assert has_element?(live, "#no-results-alert")
    end

    test "report executes for 3 users - some results", %{conn: conn} do
      user1 = AccountFixtures.user_fixture()
      user2 = AccountFixtures.user_fixture()
      user3 = AccountFixtures.user_fixture()
      create_minute_data([user1, user2, user3])

      {:ok, live, _html} =
        live(
          conn,
          ~p"/moderation/tools/time_compare?date=2021-01-01&user1=#{user1.id}&user2=#{user2.id}&user3=#{user3.id}"
        )

      assert has_element?(live, "#time_compare-form")
      refute has_element?(live, "#no-results-alert")
    end
  end

  defp auth(_state) do
    TeiserverTestLib.moderator_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end

  defp create_minute_data(users) do
    user_ids = Enum.map(users, fn u -> u.id end)
    [u1, u2 | remaining] = user_ids

    [
      %{
        "timestamp" => DateTime.new!(~D[2021-01-01], ~T[01:01:00], "Etc/UTC"),
        "data" => %{
          "battle" => %{"in_progress" => 1, "lobby" => 2, "total" => 3},
          "client" => %{
            "lobby" => user_ids,
            "menu" => [],
            "player" => [],
            "spectator" => [],
            "total" => user_ids
          }
        }
      },
      %{
        "timestamp" => DateTime.new!(~D[2021-01-01], ~T[01:02:00], "Etc/UTC"),
        "data" => %{
          "battle" => %{"in_progress" => 1, "lobby" => 2, "total" => 3},
          "client" => %{
            "lobby" => remaining,
            "menu" => [],
            "player" => [u1],
            "spectator" => [u2],
            "total" => user_ids
          }
        }
      },
      %{
        "timestamp" => DateTime.new!(~D[2021-01-01], ~T[01:03:00], "Etc/UTC"),
        "data" => %{
          "battle" => %{"in_progress" => 4, "lobby" => 4, "total" => 8},
          "client" => %{
            "lobby" => remaining,
            "menu" => [],
            "player" => [u1],
            "spectator" => [u2],
            "total" => user_ids
          }
        }
      },
      # Another segment
      %{
        "timestamp" => DateTime.new!(~D[2021-01-01], ~T[10:23:00], "Etc/UTC"),
        "data" => %{
          "battle" => %{"in_progress" => 4, "lobby" => 4, "total" => 8},
          "client" => %{
            "lobby" => remaining,
            "menu" => [],
            "player" => [u1],
            "spectator" => [u2],
            "total" => user_ids
          }
        }
      }
    ]
    |> Enum.map(fn params ->
      Logging.create_server_minute_log(params)
    end)
  end
end
