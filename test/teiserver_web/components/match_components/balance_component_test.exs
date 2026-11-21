defmodule TeiserverWeb.MatchComponents.BalanceComponentTest do
  alias Teiserver.Battle.BalanceLib
  alias Teiserver.TeiserverTestLib
  alias TeiserverWeb.MatchComponents.BalanceComponent

  use TeiserverWeb.ConnCase, async: true

  # Creates a real user and wraps it as a match member. The balance tab needs
  # real users because BalanceLib looks up names and stats from the database.
  #
  # Parameters:
  #   * `team_id` - zero based team id the player had in the match
  #   * `party_id` - optional party id, defaults to `nil`
  defp create_member(team_id, party_id \\ nil) do
    user = TeiserverTestLib.new_user()
    %{user_id: user.id, team_id: team_id, party_id: party_id, user: user}
  end

  # Builds a rating log entry as the show page passes it in (post-game values
  # plus the "old_rating_value" added by the show page).
  #
  # Parameters:
  #   * `old_rating_value` - rating before the match, used for balancing and sorting
  defp build_rating_log(old_rating_value) do
    %{
      value: %{
        "rating_value" => old_rating_value + 1.0,
        "rating_value_change" => 1.0,
        "uncertainty" => 6.0,
        "uncertainty_change" => -1.0,
        "old_rating_value" => old_rating_value
      }
    }
  end

  # Renders the balance tab for a two team match.
  #
  # Parameters:
  #   * `members` - match members, see create_member/2
  #   * `ratings` - list of old rating values, in the same order as `members`
  #   * `algorithm` - name of the balance algorithm, see BalanceLib.algorithm_modules/0
  #   * `parties` - map of `party_id => {colour, icon}`, defaults to `%{}`
  defp render_balance(members, ratings, algorithm, parties \\ %{}) do
    rating_logs =
      members
      |> Enum.zip(ratings)
      |> Map.new(fn {m, rating} -> {m.user_id, build_rating_log(rating)} end)

    render_component(&BalanceComponent.balance_tab/1, %{
      algorithm_options: BalanceLib.get_allowed_algorithms(true),
      algorithm: algorithm,
      match: %{team_count: 2, team_size: div(Enum.count(members), 2), members: members},
      members: members,
      rating_logs: rating_logs,
      parties: parties
    })
  end

  # Reads the member table (the only table-sm in the balance tab) and returns
  # one map per row.
  #
  # Parameters:
  #   * `html` - the rendered balance tab
  defp member_rows(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("table.table-sm tbody tr")
    |> Enum.map(fn row ->
      [name, _party, team, rating, _uncertainty] =
        row |> Floki.find("td") |> Enum.map(&(&1 |> Floki.text() |> String.trim()))

      %{name: name, team: String.to_integer(team), rating: String.to_float(rating)}
    end)
  end

  describe "BalanceComponent.get_team_id" do
    test "get team id" do
      team_players = %{1 => [1, 4], 2 => [2, 3]}
      player_id = 4
      result = BalanceComponent.get_team_id(player_id, team_players)
      assert result == 0

      player_id = 3
      result = BalanceComponent.get_team_id(player_id, team_players)
      assert result == 1
    end

    test "works for more than two teams" do
      team_players = %{1 => [1], 2 => [2], 3 => [3], 4 => [4]}

      # Team keys start at 1, the returned team id starts at 0
      assert BalanceComponent.get_team_id(4, team_players) == 3
    end

    test "raises when the player is in none of the teams" do
      # Enum.find/2 returns nil, which does not match {team_id, _players}
      assert_raise MatchError, fn ->
        BalanceComponent.get_team_id(99, %{1 => [1], 2 => [2]})
      end
    end
  end

  describe "BalanceComponent.balance_tab" do
    test "renders both balance sections and every rated member" do
      members = [create_member(0), create_member(0), create_member(1), create_member(1)]
      html = render_balance(members, [30.0, 25.0, 20.0, 15.0], "loser_picks")

      assert html =~ "Based on data at the time"
      assert html =~ "If balance was made using current ratings"

      # The algorithm dropdown has the selected algorithm preselected
      assert html =~ ~s(<option selected value="loser_picks">)

      rows = member_rows(html)
      assert Enum.count(rows) == 4

      # Every member shows up with the pre-game rating (rating_value - rating_value_change)
      assert rows |> Enum.map(& &1.name) |> Enum.sort() ==
               members |> Enum.map(& &1.user.name) |> Enum.sort()

      assert rows |> Enum.map(& &1.rating) |> Enum.sort() == [15.0, 20.0, 25.0, 30.0]
    end

    test "sorts the members by team and then by rating" do
      members = [create_member(0), create_member(0), create_member(1), create_member(1)]
      rows = render_balance(members, [15.0, 30.0, 20.0, 25.0], "loser_picks") |> member_rows()

      # The team column shows the team the balancer picked (1 or 2), not the
      # team from the match, and both teams get two players
      assert rows |> Enum.map(& &1.team) == [1, 1, 2, 2]

      # Within a team the highest rating comes first
      for team <- [1, 2] do
        ratings = rows |> Enum.filter(&(&1.team == team)) |> Enum.map(& &1.rating)
        assert ratings == Enum.sort(ratings, :desc)
      end
    end

    test "members without a rating log are left out of the member table" do
      members = [create_member(0), create_member(0), create_member(1), create_member(1)]
      unrated = create_member(1)

      # Only the first four members get a rating log
      html =
        render_component(&BalanceComponent.balance_tab/1, %{
          algorithm_options: BalanceLib.get_allowed_algorithms(true),
          algorithm: "loser_picks",
          match: %{team_count: 2, team_size: 2, members: members},
          members: members ++ [unrated],
          rating_logs:
            members
            |> Enum.zip([30.0, 25.0, 20.0, 15.0])
            |> Map.new(fn {m, r} -> {m.user_id, build_rating_log(r)} end),
          parties: %{}
        })

      rows = member_rows(html)
      assert Enum.count(rows) == 4
      refute Enum.any?(rows, &(&1.name == unrated.user.name))
    end

    test "keeps a party that fits into a balanced team together and shows the party icon" do
      members = [
        create_member(0, "party-1"),
        create_member(0, "party-1"),
        create_member(1),
        create_member(1)
      ]

      parties = %{"party-1" => {"#00AA00", "dice-one"}}

      # The party (30 + 15) is exactly as strong as the two solo players (25 + 20),
      # so loser_picks can keep the party together. force_party currently only
      # calls loser_picks, it does not force anything for unbalanced parties.
      html = render_balance(members, [30.0, 15.0, 25.0, 20.0], "loser_picks", parties)

      assert html =~ "dice-one"

      party_names = members |> Enum.take(2) |> Enum.map(& &1.user.name)

      party_teams =
        html
        |> member_rows()
        |> Enum.filter(&(&1.name in party_names))
        |> Enum.map(& &1.team)
        |> Enum.uniq()

      assert Enum.count(party_teams) == 1
    end

    test "renders with every balance algorithm" do
      members = [create_member(0), create_member(0), create_member(1), create_member(1)]

      # "default" is offered in the dropdown but is not a real algorithm module,
      # so we only check the algorithms BalanceLib can actually run
      for algorithm <- Map.keys(BalanceLib.algorithm_modules()) do
        rows = render_balance(members, [30.0, 25.0, 20.0, 15.0], algorithm) |> member_rows()

        assert Enum.count(rows) == 4, "#{algorithm} did not render all members"
        assert rows |> Enum.map(& &1.team) |> Enum.frequencies() == %{1 => 2, 2 => 2}
      end
    end
  end
end
