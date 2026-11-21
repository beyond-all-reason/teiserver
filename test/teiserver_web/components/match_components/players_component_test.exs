defmodule TeiserverWeb.MatchComponents.PlayersComponentTest do
  alias TeiserverWeb.MatchComponents.PlayersComponent

  use TeiserverWeb.ConnCase, async: true

  # Builds a minimal match member without a party.
  #
  # Parameters:
  #   * `user_id` - id of the user, also used as `user.id`
  #   * `name` - display name of the user
  #   * `team_id` - zero based team id
  #   * `exit_status` - `:stayed`, `:early`, `:abandoned` or `:noshow`, defaults to `:stayed`
  #   * `left_after` - seconds after which the player left, like `game_duration`;
  #     defaults to `nil`
  defp build_member(user_id, name, team_id, exit_status \\ :stayed, left_after \\ nil) do
    %{
      user_id: user_id,
      team_id: team_id,
      party_id: nil,
      exit_status: exit_status,
      left_after: left_after,
      user: %{id: user_id, name: name, colour: "#AA0000", icon: "fa-solid fa-user"}
    }
  end

  # Builds a rating log entry with fixed skill and uncertainty. The players tab
  # shows the "old_*" (pre-game) values and uses old_skill/old_uncertainty for
  # the Openskill win prediction.
  #
  # Parameters:
  #   * `rating_value` - pre-game rating shown in the table
  defp build_rating_log(rating_value) do
    %{
      value: %{
        "old_rating_value" => rating_value,
        "old_uncertainty" => 5.0,
        "old_num_matches" => 10,
        "old_skill" => 25.0
      }
    }
  end

  # Renders the players tab for a match that lasted 1000 seconds and was won by team 0.
  #
  # Parameters:
  #   * `members` - match members, see build_member/5
  #   * `rating_logs` - map of `user_id => rating log`, see build_rating_log/1
  #   * `current_user_id` - id of the logged in user
  defp render_players(members, rating_logs, current_user_id) do
    render_component(&PlayersComponent.players_tab/1, %{
      members: members,
      match: %{winning_team: 0, game_duration: 1000},
      rating_logs: rating_logs,
      parties: %{},
      current_user: %{id: current_user_id}
    })
  end

  describe "PlayersComponent.players_tab" do
    test "renders a row with rating data for every member" do
      members = [
        build_member(1, "PlayersOne", 0),
        build_member(2, "PlayersTwo", 1)
      ]

      rating_logs = %{1 => build_rating_log(21.0), 2 => build_rating_log(19.0)}

      html = render_players(members, rating_logs, 999)

      assert html =~ "PlayersOne"
      assert html =~ "PlayersTwo"
      assert html =~ "21.0"
      assert html =~ "19.0"
    end

    test "shows report and accolade buttons for everyone except the current user" do
      members = [
        build_member(1, "CurrentUser", 0),
        build_member(2, "OtherUser", 1)
      ]

      # The current user is member 1, so only member 2 can be reported
      html = render_players(members, %{}, 1)

      assert html =~ "/moderation/report_user/2"
      refute html =~ "/moderation/report_user/1"

      # Exactly one accolade button, for the other user
      assert html |> String.split("give-accolade") |> length() == 2
      assert html =~ ~s(phx-value-recipient_name="OtherUser")

      # The accolade button carries the team of the current user
      assert html =~ ~s(phx-value-current_user_team_id="0")
    end

    test "shows the play percentage for players who left early or abandoned" do
      members = [
        build_member(1, "StayedPlayer", 0),
        # Left after 250 of 1000 seconds -> 25%
        build_member(2, "EarlyPlayer", 0, :early, 250),
        # Left after 500 of 1000 seconds -> 50%
        build_member(3, "AbandonedPlayer", 1, :abandoned, 500),
        build_member(4, "NoshowPlayer", 1, :noshow, 0)
      ]

      html = render_players(members, %{}, 999)

      # Each exit status has its own icon
      assert html =~ "fa-clock"
      assert html =~ "fa-person-running"
      assert html =~ "fa-user-ninja"

      assert html =~ "25%"
      assert html =~ "50%"
    end

    test "shows the Openskill prediction for a rated two team match" do
      members = [
        build_member(1, "TeamOneA", 0),
        build_member(2, "TeamOneB", 0),
        build_member(3, "TeamTwoA", 1),
        build_member(4, "TeamTwoB", 1)
      ]

      # Every player has the same skill, so both teams have a 50% chance
      rating_logs = Map.new(1..4, fn id -> {id, build_rating_log(20.0)} end)

      html = render_players(members, rating_logs, 999)

      assert html =~ "Openskill library win predict"
      assert html =~ "[50.0%, 50.0%]"
      assert html =~ "Team skill"
      assert html =~ "Team uncertainty squared"
    end

    test "does not show a prediction for unrated matches" do
      members = [build_member(1, "TeamOne", 0), build_member(2, "TeamTwo", 1)]

      # An unrated match has no rating logs at all
      html = render_players(members, %{}, 999)

      refute html =~ "Openskill library win predict"
    end
  end
end
