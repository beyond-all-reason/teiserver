defmodule TeiserverWeb.MatchComponents.OverviewComponentTest do
  alias TeiserverWeb.MatchComponents.OverviewComponent

  use TeiserverWeb.ConnCase, async: true

  # Builds a match with two bots and three tags.
  defp build_match do
    %{
      team_count: 2,
      team_size: 4,
      started: ~U[2026-01-01 12:00:00Z],
      finished: ~U[2026-01-01 12:30:00Z],
      game_duration: 1800,
      tags: %{"tag_a" => 1, "tag_b" => 2, "tag_c" => 3},
      founder: %{name: "OverviewHost"},
      bots: %{"bot_one" => %{}, "bot_two" => %{}},
      data: %{"overview_data_key" => "overview_data_value"}
    }
  end

  # Renders the overview tab for the match from build_match/0.
  # `allow?/2` accepts any map with an id and roles, no real user record is needed.
  #
  # Parameters:
  #   * `roles` - roles of the current user, e.g. `["Moderator"]`; with `["Server"]`
  #     every permission (including "admin.dev") is granted
  defp render_overview(roles) do
    render_component(&OverviewComponent.overview_tab/1, %{
      match: build_match(),
      tz: "UTC",
      current_user: %{id: 1, roles: roles}
    })
  end

  describe "OverviewComponent.overview_tab" do
    test "shows the basic match information to every user" do
      html = render_overview([])

      # Values taken straight from the match
      assert html =~ "Team count:</strong> 2"
      assert html =~ "Team size:</strong> 4"
      assert html =~ "OverviewHost"

      # Started/finished are formatted as ymd_hms in the given timezone
      assert html =~ "2026-01-01 12:00:00"
      assert html =~ "2026-01-01 12:30:00"

      # The bots map has two entries, so we expect a count of 2
      assert html =~ "Bot count:</strong> 2"
    end

    test "hides tag count and raw match data from normal users" do
      html = render_overview([])

      # "Tag count" needs admin.dev, the raw data textareas need Moderator
      refute html =~ "Tag count"
      refute html =~ "Match data"
      refute html =~ "overview_data_key"
    end

    test "moderators see the raw match data but not the tag count" do
      html = render_overview(["Moderator"])

      # Moderator does not contain admin.dev
      refute html =~ "Tag count"

      # The match data and the bots are dumped as pretty printed JSON
      assert html =~ "Match data"
      assert html =~ "overview_data_key"
      assert html =~ "overview_data_value"
      assert html =~ "Match bots"
      assert html =~ "bot_one"
    end

    test "server users see the tag count and the raw match data" do
      html = render_overview(["Server"])

      # Three tags in build_match/0
      assert html =~ "Tag count:</strong> 3"
      assert html =~ "Match data"
    end
  end
end
