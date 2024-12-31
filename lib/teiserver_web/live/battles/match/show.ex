defmodule TeiserverWeb.Battle.MatchLive.Show do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.{Battle, Game, Telemetry}
  alias Teiserver.Battle.{MatchLib, BalanceLib}
  alias Teiserver.Helper.NumberHelper

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:site_menu_active, "match")
      |> assign(:view_colour, Teiserver.Battle.MatchLib.colours())
      |> assign(:tab, "details")
      |> assign(
        :algorithm_options,
        BalanceLib.get_allowed_algorithms(true)
      )
      |> assign(:algorithm, BalanceLib.get_default_algorithm())

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _url, socket) do
    socket =
      socket
      |> assign(:id, String.to_integer(id))
      |> get_match()
      |> assign(:tab, socket.assigns.live_action)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(%{assigns: %{match_name: match_name}} = socket, :overview, _params) do
    socket
    |> assign(:page_title, "#{match_name} - Overview")
  end

  defp apply_action(%{assigns: %{match_name: match_name}} = socket, :players, _params) do
    socket
    |> assign(:page_title, "#{match_name} - Players")
  end

  defp apply_action(%{assigns: %{match_name: match_name}} = socket, :ratings, _params) do
    socket
    |> mount_require_any(["Overwatch"])
    |> assign(:page_title, "#{match_name} - Ratings")
  end

  defp apply_action(%{assigns: %{match_name: match_name}} = socket, :events, _params) do
    socket
    |> mount_require_any(["Overwatch"])
    |> assign(:page_title, "#{match_name} - Events")
  end

  defp apply_action(%{assigns: %{match_name: match_name}} = socket, :balance, _params) do
    # Restrict the balance tab to certain roles.
    # Note that Staff roles like Contributor will inherit Tester permissions
    socket
    |> mount_require_any(["Reviewer", "Tester"])
    |> assign(:page_title, "#{match_name} - Balance")
  end

  # @impl true
  # def handle_event("tab-select", %{"tab" => tab}, socket) do
  #   {:noreply, assign(socket, :tab, tab)}
  # end

  defp get_match(
         %{assigns: %{id: id, algorithm: algorithm, current_user: _current_user}} = socket
       ) do
    if connected?(socket) do
      match =
        Battle.get_match!(id,
          preload: [:members_and_users, :founder]
        )

      match_name = MatchLib.make_match_name(match)

      members =
        match.members
        |> Enum.map(fn member ->
          Map.merge(member, %{
            exit_status: MatchLib.calculate_exit_status(member.left_after, match.game_duration)
          })
        end)
        |> Enum.sort_by(fn m -> m.user.name end, &<=/2)
        |> Enum.sort_by(fn m -> m.team_id end, &<=/2)

      # For unprocessed or unrated matches this will return %{}
      rating_logs =
        Game.list_rating_logs(
          search: [
            match_id: match.id
          ],
          limit: :infinity
        )
        |> Map.new(fn log -> {log.user_id, get_prematch_log(log)} end)

      prediction_text = get_prediction_text(rating_logs, members)

      # Creates a map where the party_id refers to an integer
      # but only includes parties with 2 or more members
      parties =
        members
        |> Enum.group_by(fn m -> m.party_id end)
        |> Map.drop([nil])
        |> Map.filter(fn {_id, members} -> Enum.count(members) > 1 end)
        |> Map.keys()
        |> Enum.zip(Teiserver.Helper.StylingHelper.bright_hex_colour_list())
        |> Enum.zip(~w(dice-one dice-two dice-three dice-four dice-five dice-six))
        |> Enum.map(fn {{party_id, colour}, idx} ->
          {party_id, {colour, idx}}
        end)
        |> Map.new()

      # Now for balance related stuff
      partied_players =
        members
        |> Enum.group_by(fn p -> p.party_id end, fn p -> p.user_id end)

      groups =
        partied_players
        |> Enum.map(fn
          # The nil group is players without a party, they need to
          # be broken out of the party
          {nil, player_id_list} ->
            player_id_list
            |> Enum.filter(fn userid -> rating_logs[userid] != nil end)
            |> Enum.map(fn userid ->
              %{userid => rating_logs[userid].value}
            end)

          {_party_id, player_id_list} ->
            player_id_list
            |> Enum.filter(fn userid -> rating_logs[userid] != nil end)
            |> Map.new(fn userid ->
              {userid, rating_logs[userid].value}
            end)
        end)
        |> List.flatten()

      past_balance =
        BalanceLib.create_balance(groups, match.team_count,
          algorithm: algorithm,
          debug_mode?: true
        )
        |> Map.put(:balance_mode, :grouped)

      # What about new balance?
      new_balance = generate_new_balance_data(match, algorithm)

      raw_events =
        Telemetry.list_simple_match_events(where: [match_id: match.id], preload: [:event_types])

      events_by_type =
        raw_events
        |> Enum.group_by(
          fn e ->
            e.event_type.name
          end,
          fn _ ->
            1
          end
        )
        |> Enum.map(fn {name, vs} ->
          {name, Enum.count(vs)}
        end)
        |> Enum.sort_by(fn v -> v end, &<=/2)

      team_lookup =
        members
        |> Map.new(fn m ->
          {m.user_id, m.team_id}
        end)

      events_by_team_and_type =
        raw_events
        |> Enum.group_by(
          fn e ->
            {team_lookup[e.user_id] || -1, e.event_type.name}
          end,
          fn _ ->
            1
          end
        )
        |> Enum.map(fn {key, vs} ->
          {key, Enum.count(vs)}
        end)
        |> Enum.sort_by(fn v -> v end, &<=/2)

      balanced_members =
        cond do
          # It will go here if the match is unprocessed or if there are no rating logs e.g. unrated match
          rating_logs == %{} ->
            []

          true ->
            Enum.map(members, fn x ->
              team_id = get_team_id(x.user_id, past_balance.team_players)
              Map.put(x, :team_id, team_id)
            end)
            |> Enum.sort_by(fn m -> rating_logs[m.user.id].value["rating_value"] end, &>=/2)
            |> Enum.sort_by(fn m -> m.team_id end, &<=/2)
        end

      game_id =
        cond do
          match.game_id -> match.game_id
          match.data -> match.data["export_data"]["gameId"]
          true -> nil
        end

      replay =
        if game_id do
          Application.get_env(:teiserver, Teiserver)[:main_website] <>
            "/replays?gameId=" <> game_id
        end

      match_rating_status = get_match_rating_status(match)

      socket
      |> assign(:match, match)
      |> assign(:match_name, match_name)
      |> assign(:members, members)
      |> assign(:balanced_members, balanced_members)
      |> assign(:rating_logs, rating_logs)
      |> assign(:parties, parties)
      |> assign(:past_balance, past_balance)
      |> assign(:new_balance, new_balance)
      |> assign(:events_by_type, events_by_type)
      |> assign(:events_by_team_and_type, events_by_team_and_type)
      |> assign(:replay, replay)
      |> assign(:rating_status, match_rating_status)
      |> assign(:prediction_text, prediction_text)
    else
      socket
      |> assign(:match, nil)
      |> assign(:match_name, "Loading...")
      |> assign(:members, [])
      |> assign(:rating_logs, [])
      |> assign(:parties, %{})
      |> assign(:past_balance, %{})
      |> assign(:new_balance, %{})
      |> assign(:events_by_type, %{})
      |> assign(:events_by_team_and_type, %{})
      |> assign(:replay, nil)
      |> assign(:rating_status, nil)
      |> assign(:prediction_text, [])
    end
  end

  defp get_prediction_text(rating_logs, members) do
    if(rating_logs == %{}) do
      # Unrated match will not have rating logs
      []
    else
      simple_rating_logs =
        Enum.map(members, fn m ->
          logs = rating_logs[m.user_id].value

          %{
            team_id: m.team_id,
            old_skill: logs["old_skill"],
            old_uncertainty: logs["old_uncertainty"]
          }
        end)
        |> Enum.group_by(fn x -> x.team_id end)
        |> Enum.map(fn {_key, value} ->
          Enum.map(value, fn y ->
            {y.old_skill, y.old_uncertainty}
          end)
        end)

      # predict_win may not be reliable if team count not equal to 2
      if length(simple_rating_logs) == 2 do
        prediction = Openskill.predict_win(simple_rating_logs)

        prediction_text_values =
          Enum.map(prediction, fn x ->
            percentage = (x * 100) |> NumberHelper.round(1)
            "#{percentage}%"
          end)

        team_ratings =
          Openskill.Util.team_rating(simple_rating_logs)

        skill_text_values =
          Enum.map(team_ratings, fn {skill, _sigma_sq, _extra1, _extra2} ->
            "#{skill |> NumberHelper.round(1)}"
          end)

        uncertainty_text_values =
          Enum.map(team_ratings, fn {_skill, sigma_sq, _extra1, _extra2} ->
            "#{sigma_sq |> NumberHelper.round(1)}"
          end)

        [
          %{
            label: "Openskill library win predict: ",
            value: "[#{prediction_text_values |> Enum.join(", ")}]"
          },
          %{
            label: "Team skill (μ): ",
            value: "[#{skill_text_values |> Enum.join(", ")}]"
          },
          %{
            label: "Team uncertainty squared (σ²): ",
            value: "[#{uncertainty_text_values |> Enum.join(", ")}]"
          }
        ]
      else
        []
      end
    end
  end

  # Adjust the logs so that we use the prematch values of rating/uncertainty
  # Prematch values are more relevant to understanding balance logs
  defp get_prematch_log(log) do
    %{
      "rating_value" => rating_value,
      "uncertainty" => uncertainty,
      "rating_value_change" => rating_value_change,
      "uncertainty_change" => uncertainty_change,
      "skill" => skill,
      "skill_change" => skill_change
    } = log.value

    old_rating = rating_value - rating_value_change
    old_uncertainty = uncertainty - uncertainty_change
    old_skill = skill - skill_change

    new_log_value =
      Map.put(log.value, "old_rating_value", old_rating)
      |> Map.put("old_uncertainty", old_uncertainty)
      |> Map.put("old_skill", old_skill)

    Map.put(log, :value, new_log_value)
  end

  def get_team_id(player_id, team_players) do
    {team_id, _players} =
      Enum.find(team_players, fn {_k, player_ids} ->
        Enum.any?(player_ids, fn x -> x == player_id end)
      end)

    # team_id should start at 0 even though first key is 1
    team_id - 1
  end

  defp generate_new_balance_data(match, algorithm) do
    # For the section "If balance we made using current ratings", do not fuzz ratings
    # This means the rating used is exactly equal to what is stored in database
    fuzz_multiplier = 0
    rating_type = MatchLib.game_type(match.team_size, match.team_count)

    partied_players =
      match.members
      |> Enum.group_by(fn p -> p.party_id end, fn p -> p.user_id end)

    groups =
      partied_players
      |> Enum.map(fn
        # The nil group is players without a party, they need to
        # be broken out of the party
        {nil, player_id_list} ->
          player_id_list
          |> Enum.map(fn userid ->
            %{userid => BalanceLib.get_user_rating_rank(userid, rating_type, fuzz_multiplier)}
          end)

        {_party_id, player_id_list} ->
          player_id_list
          |> Map.new(fn userid ->
            {userid, BalanceLib.get_user_rating_rank(userid, rating_type, fuzz_multiplier)}
          end)
      end)
      |> List.flatten()

    BalanceLib.create_balance(groups, match.team_count, algorithm: algorithm, debug_mode?: true)
    |> Map.put(:balance_mode, :grouped)
  end

  defp get_match_rating_status(match) do
    # Expecting to return an error explaining current match rating status
    # Unprocessed matches and matches with existing rating logs won't be rated again
    {_, rating_status} = Teiserver.Game.MatchRatingLib.rate_match(match)

    case rating_status do
      :invalid_game_type ->
        {"success", "Unrated game type"}

      :not_processed ->
        {"danger", "Match not processed!"}

      :no_winning_team ->
        {"warning", "Match not rated due to no winning team!"}

      :uneven_team_size ->
        {"warning", "Match not rated due to uneven team size!"}

      :not_enough_teams ->
        {"primary", "Match not rated due to not enough teams!"}

      :too_short ->
        {"warning", "Match too short to be rated!"}

      :unranked_tag ->
        {"info", "Match not rated due to unrated modoption!"}

      :already_rated ->
        {"success", "Match rated successfully"}

      :cheating_enabled ->
        {"warning", "Match not rated due to cheating enabled!"}

      :no_match ->
        {"danger", "No match!"}
    end
  end

  @doc """
  Handles the dropdown for algorithm changing
  """
  @impl true
  def handle_event("update-algorithm", event, socket) do
    [key] = event["_target"]
    value = event[key]

    {:noreply,
     socket
     |> assign(:algorithm, value)
     |> get_match()}
  end
end
