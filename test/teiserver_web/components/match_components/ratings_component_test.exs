defmodule TeiserverWeb.MatchComponents.RatingsComponentTest do
  alias TeiserverWeb.MatchComponents.RatingsComponent

  use TeiserverWeb.ConnCase, async: true

  # Builds a minimal match member.
  #
  # Parameters:
  #   * `user_id` - id of the user, also used as `user.id`
  #   * `name` - display name of the user
  #   * `team_id` - zero based team id
  #   * `party_id` - optional party id, defaults to `nil`
  defp build_member(user_id, name, team_id, party_id \\ nil) do
    %{
      user_id: user_id,
      team_id: team_id,
      party_id: party_id,
      user: %{id: user_id, name: name, colour: "#AA0000", icon: "fa-solid fa-user"}
    }
  end

  # Builds a rating log entry. Rating logs are keyed by user id; the component
  # only reads the post-game rating value and the change caused by this match.
  #
  # Parameters:
  #   * `rating_value` - rating after the match
  #   * `rating_value_change` - rating change caused by the match, negative for a loss
  defp build_rating_log(rating_value, rating_value_change) do
    %{value: %{"rating_value" => rating_value, "rating_value_change" => rating_value_change}}
  end

  describe "RatingsComponent.ratings_tab" do
    test "renders pre-game rating, post-game rating and change for each member" do
      members = [
        build_member(1, "RatingsWinner", 0),
        build_member(2, "RatingsLoser", 1)
      ]

      rating_logs = %{
        1 => build_rating_log(20.0, 2.5),
        2 => build_rating_log(15.0, -1.5)
      }

      html =
        render_component(&RatingsComponent.ratings_tab/1, %{
          members: members,
          rating_logs: rating_logs,
          parties: %{},
          match: %{winning_team: 0}
        })

      assert html =~ "RatingsWinner"
      assert html =~ "RatingsLoser"

      # Pre-game rating is calculated as rating_value - rating_value_change
      assert html =~ "17.5"
      assert html =~ "16.5"

      # Post-game ratings are shown as they are
      assert html =~ "20.0"
      assert html =~ "15.0"

      # A positive change is green, a negative change is red
      assert html =~ "text-success"
      assert html =~ "text-danger"

      # Only the winning team gets a trophy, here that is exactly one member
      assert html |> String.split("fa-trophy") |> length() == 2
    end

    test "members without a rating log still get a row but no rating values" do
      html =
        render_component(&RatingsComponent.ratings_tab/1, %{
          members: [build_member(1, "UnratedPlayer", 0)],
          rating_logs: %{},
          parties: %{},
          match: %{winning_team: 1}
        })

      assert html =~ "UnratedPlayer"

      # Without a rating the change cell falls back to the neutral colour
      assert html =~ "text-warning"
      refute html =~ "text-success"
      refute html =~ "text-danger"

      # The member is not on the winning team
      refute html =~ "fa-trophy"
    end

    test "members of a party get the party icon" do
      # The show page builds parties as %{party_id => {colour, icon}}
      parties = %{"party-1" => {"#00AA00", "dice-one"}}

      html =
        render_component(&RatingsComponent.ratings_tab/1, %{
          members: [
            build_member(1, "PartyMemberOne", 0, "party-1"),
            build_member(2, "PartyMemberTwo", 0, "party-1")
          ],
          rating_logs: %{},
          parties: parties,
          match: %{winning_team: 0}
        })

      assert html =~ "dice-one"
    end
  end
end
