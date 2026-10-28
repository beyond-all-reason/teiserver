defmodule TeiserverWeb.MatchComponents.EventsComponentTest do
  alias Ecto.UUID
  alias Teiserver.Battle
  alias Teiserver.TeiserverTestLib
  alias Teiserver.Telemetry
  alias TeiserverWeb.MatchComponents.EventsComponent

  use TeiserverWeb.ConnCase, async: true

  # Creates a finished duel in the database.
  #
  # Parameters:
  #   * `user` - user that is stored as the founder of the match
  defp create_match(user) do
    {:ok, match} =
      Battle.create_match(%{
        uuid: UUID.generate(),
        server_uuid: UUID.generate(),
        map: "Comet Catcher",
        tags: %{},
        team_count: 2,
        team_size: 1,
        passworded: false,
        game_type: "Duel",
        founder_id: user.id,
        bots: %{},
        started: DateTime.utc_now(:second),
        finished: DateTime.utc_now(:second)
      })

    match
  end

  describe "EventsComponent.events_tab" do
    test "renders the given events by type and groups the loaded events by team" do
      user = TeiserverTestLib.new_user()
      match = create_match(user)

      # Two events of the same type for one user, which is on team 0
      {:ok, _event} = Telemetry.log_simple_match_event(user.id, match.id, "events_tab_test", 100)
      {:ok, _event} = Telemetry.log_simple_match_event(user.id, match.id, "events_tab_test", 200)

      html =
        render_component(&EventsComponent.events_tab/1, %{
          match_id: match.id,
          members: [%{user_id: user.id, team_id: 0}],
          # events_by_type is calculated by the show page and passed in as is
          events_by_type: [{"passed_in_event", 7}]
        })

      assert html =~ "By type"
      assert html =~ "passed_in_event"
      assert html =~ "7"

      # The "by team and type" table is built from the database events:
      # team 0 is shown as team 1 and both events are counted together
      assert html =~ "By team and type"
      assert html =~ "events_tab_test"

      assert html =~
               ~r/<td[^>]*>\s*1\s*<\/td>\s*<td[^>]*>\s*events_tab_test\s*<\/td>\s*<td[^>]*>\s*2\s*<\/td>/
    end

    test "renders empty tables for a match without events" do
      user = TeiserverTestLib.new_user()
      match = create_match(user)

      html =
        render_component(&EventsComponent.events_tab/1, %{
          match_id: match.id,
          members: [],
          events_by_type: []
        })

      # The headers are still there, but no events
      assert html =~ "By type"
      assert html =~ "By team and type"
      refute html =~ "events_tab_test"
    end
  end
end
