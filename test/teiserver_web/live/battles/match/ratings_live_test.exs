defmodule TeiserverWeb.Battle.MatchLive.RatingsLiveTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Battle
  alias Teiserver.Game
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase, async: true

  test "battle ratings endpoints requires authentication" do
    {:ok, kw} =
      GeneralTestLib.conn_setup([], [:no_login])
      |> TeiserverTestLib.conn_setup()

    {:ok, conn} = Keyword.fetch(kw, :conn)

    conn = get(conn, ~p"/battle/ratings")
    assert redirected_to(conn) == ~p"/login"
  end

  test "can access battle ratings when authenticated" do
    {:ok, kw} =
      GeneralTestLib.conn_setup()
      |> TeiserverTestLib.conn_setup()

    {:ok, conn} = Keyword.fetch(kw, :conn)

    conn = get(conn, ~p"/battle/ratings")
    html_response(conn, 200)
  end

  test "match rows navigate without a stretched link overlay" do
    {:ok, kw} =
      GeneralTestLib.conn_setup()
      |> TeiserverTestLib.conn_setup()

    {:ok, conn} = Keyword.fetch(kw, :conn)
    {:ok, user} = Keyword.fetch(kw, :user)
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    rating_type_id = MatchRatingLib.rating_type_name_lookup()["Large Team"]

    {:ok, match} =
      Battle.create_match(%{
        uuid: Ecto.UUID.generate(),
        server_uuid: Ecto.UUID.generate(),
        map: "Comet Catcher",
        tags: %{},
        team_count: 2,
        team_size: 8,
        passworded: false,
        game_type: "Large Team",
        founder_id: user.id,
        bots: %{},
        started: now,
        finished: now
      })

    {:ok, _membership} =
      Battle.create_match_membership(%{
        match_id: match.id,
        user_id: user.id,
        team_id: 0,
        win: true
      })

    {:ok, _rating_log} =
      Game.create_rating_log(%{
        user_id: user.id,
        rating_type_id: rating_type_id,
        match_id: match.id,
        season: MatchRatingLib.active_season(),
        inserted_at: now,
        value: %{
          "skill" => 25.0,
          "skill_change" => 1.0,
          "uncertainty" => 5.0,
          "uncertainty_change" => -1.0,
          "rating_value" => 20.0,
          "rating_value_change" => 2.0
        }
      })

    {:ok, view, _html} = live(conn, ~p"/battle/ratings")

    assert has_element?(view, "tr[phx-click] a[href='/battle/#{match.id}']", "Show")
    refute has_element?(view, ".stretched-link")
    refute has_element?(view, "tr.position-relative")
  end
end
