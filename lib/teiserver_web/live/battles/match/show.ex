defmodule TeiserverWeb.Battle.MatchLive.Show do
  @moduledoc false

  alias Openskill.Util
  alias Teiserver.Account
  alias Teiserver.Account.AccoladeLib
  alias Teiserver.Battle
  alias Teiserver.Battle.BalanceLib
  alias Teiserver.Battle.MatchLib
  alias Teiserver.Config
  alias Teiserver.Game
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Helper.NumberHelper
  alias Teiserver.Helper.StylingHelper
  alias Teiserver.Telemetry
  use TeiserverWeb, :live_view
  import Teiserver.Helpers.ComponentHelper
  import Teiserver.Helper.ColourHelper

  import TeiserverWeb.Battle.MatchLive.SubComponents.OverviewComponent
  import TeiserverWeb.Battle.MatchLive.SubComponents.PlayersComponent
  import TeiserverWeb.Battle.MatchLive.SubComponents.RatingsComponent
  import TeiserverWeb.Battle.MatchLive.SubComponents.BalanceComponent
  import TeiserverWeb.Battle.MatchLive.SubComponents.EventsComponent

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:site_menu_active, "match")
      |> assign(:view_colour, MatchLib.colours())
      |> assign(:tab, "details")
      |> assign(
        :algorithm_options,
        BalanceLib.get_allowed_algorithms(true)
      )
      |> assign(:algorithm, BalanceLib.get_default_algorithm())
      |> assign(:give_accolade, nil)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
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

  # @impl Phoenix.LiveView
  # def handle_event("tab-select", %{"tab" => tab}, socket) do
  #   {:noreply, assign(socket, :tab, tab)}
  # end

  defp get_match(
         %{assigns: %{id: id, algorithm: algorithm, current_user: current_user}} =
           socket
       ) do
    if connected?(socket) do
      match =
        Battle.get_match!(id,
          preload: [:members_and_users, :founder]
        )

      match_name = MatchLib.make_match_name(match)

      # For unprocessed or unrated matches this will return %{}
      rating_logs =
        Game.list_rating_logs(
          search: [
            match_id: match.id
          ],
          limit: :infinity
        )
        |> Map.new(fn log -> {log.user_id, get_prematch_log(log)} end)

      members =
        match.members
        |> Enum.map(fn member ->
          Map.merge(member, %{
            exit_status: MatchLib.calculate_exit_status(member.left_after, match.game_duration)
          })
        end)
        |> Enum.sort_by(
          fn m ->
            if rating_logs[m.user_id] do
              # Sort be rating descending (that's why there's a negative in front)
              -rating_logs[m.user.id].value["old_rating_value"]
            else
              # Or name ascending if unrated match
              m.user.name
            end
          end,
          &<=/2
        )
        |> Enum.sort_by(fn m -> m.team_id end, &<=/2)

      find_current_user =
        Enum.find(members, fn x ->
          x.user_id == current_user.id
        end)

      # Creates a map where the party_id refers to an integer
      # but only includes parties with 2 or more members
      parties =
        members
        |> Enum.group_by(fn m -> m.party_id end)
        |> Map.drop([nil])
        |> Map.filter(fn {_id, members} -> Enum.count(members) > 1 end)
        |> Map.keys()
        |> Enum.zip(StylingHelper.bright_hex_colour_list())
        |> Enum.zip(~w(dice-one dice-two dice-three dice-four dice-five dice-six))
        |> Enum.map(fn {{party_id, colour}, idx} ->
          {party_id, {colour, idx}}
        end)
        |> Map.new()

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

      raw_events =
        Telemetry.list_simple_match_events(where: [match_id: match.id], preload: [:event_types])

      events_by_type =
        raw_events
        |> Enum.group_by(
          fn e ->
            e.event_type.name
          end,
          fn _event ->
            1
          end
        )
        |> Enum.map(fn {name, vs} ->
          {name, Enum.count(vs)}
        end)
        |> Enum.sort_by(fn v -> v end, &<=/2)

      socket
      |> assign(:match, match)
      |> assign(:match_name, match_name)
      |> assign(:members, members)
      |> assign(:rating_logs, rating_logs)
      |> assign(:parties, parties)
      |> assign(:replay, replay)
      |> assign(:rating_status, match_rating_status)
      |> assign(:events_by_type, events_by_type)
    else
      socket
      |> assign(:match, nil)
      |> assign(:match_name, "Loading...")
      |> assign(:members, [])
      |> assign(:rating_logs, %{})
      |> assign(:parties, %{})
      |> assign(:replay, nil)
      |> assign(:rating_status, nil)
      |> assign(:events_by_type, [])
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

    num_matches = Map.get(log.value, "num_matches", nil)

    old_rating = rating_value - rating_value_change
    old_uncertainty = uncertainty - uncertainty_change
    old_skill = skill - skill_change

    old_num_matches =
      if num_matches, do: num_matches - 1, else: nil

    new_log_value =
      Map.put(log.value, "old_rating_value", old_rating)
      |> Map.put("old_uncertainty", old_uncertainty)
      |> Map.put("old_skill", old_skill)
      |> Map.put("old_num_matches", old_num_matches)

    Map.put(log, :value, new_log_value)
  end

  defp get_match_rating_status(match) do
    # Expecting to return an error explaining current match rating status
    # Unprocessed matches and matches with existing rating logs won't be rated again
    {_result, rating_status} = MatchRatingLib.rate_match(match)

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
  @impl Phoenix.LiveView
  def handle_event("update-algorithm", event, socket) do
    [key] = event["_target"]
    value = event[key]

    {:noreply,
     socket
     |> assign(:algorithm, value)
     |> get_match()}
  end

  def handle_event(
        "give-accolade",
        params,
        socket
      ) do
    recipient_id = params["recipient_id"]
    recipient_name = params["recipient_name"]
    current_user_team_id = params["current_user_team_id"]
    recipient_team_id = params["recipient_team_id"]

    is_ally? = current_user_team_id == recipient_team_id

    badge_types =
      AccoladeLib.get_giveable_accolade_types(is_ally?)

    gift_limit = Config.get_site_config_cache("teiserver.Accolade gift limit")
    gift_window = Config.get_site_config_cache("teiserver.Accolade gift window")
    user_id = socket.assigns.current_user.id
    match_id = socket.assigns.id
    {recipient_id, _rest} = Integer.parse(recipient_id)

    with {:ok, gift_count} <-
           check_gift_count(socket.assigns.current_user.id, gift_limit, gift_window),
         :ok <- check_already_gifted(user_id, recipient_id, match_id) do
      {:noreply,
       socket
       |> assign(:give_accolade, %{
         recipient: %{
           id: recipient_id,
           name: recipient_name
         },
         stage: :form,
         badge_types: badge_types,
         gift_window: gift_window,
         gift_count: gift_count,
         gift_limit: gift_limit
       })}
    else
      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:give_accolade, %{
           recipient: %{
             id: recipient_id,
             name: recipient_name
           },
           stage: :not_allowed,
           failure_reason: reason
         })}
    end
  end

  def handle_event(
        "give-accolade-submit",
        %{"badgeid" => badge_id},
        socket
      ) do
    recipient_id = socket.assigns.give_accolade.recipient.id
    current_user = socket.assigns.current_user
    match_id = socket.assigns.id

    Account.create_accolade(%{
      recipient_id: recipient_id,
      giver_id: current_user.id,
      match_id: match_id,
      inserted_at: DateTime.utc_now(),
      badge_type_id: badge_id
    })

    {:noreply,
     socket
     |> assign(:give_accolade, Map.put(socket.assigns.give_accolade, :stage, :complete))}
  end

  def handle_event(
        "return-to-match",
        _params,
        socket
      ) do
    {:noreply,
     socket
     |> assign(:give_accolade, nil)}
  end

  defp check_gift_count(user_id, gift_limit, gift_window) do
    gift_count = AccoladeLib.get_number_of_gifted_accolades(user_id, gift_window)

    if gift_count >= gift_limit do
      {:error, "You can only give #{gift_limit} accolades every #{gift_window} days."}
    else
      {:ok, gift_count}
    end
  end

  defp check_already_gifted(user_id, recipient_id, match_id) do
    if AccoladeLib.does_accolade_exist?(user_id, recipient_id, match_id) do
      {:error, "You have already given an accolade to this user for this match."}
    else
      :ok
    end
  end

  def give_accolade_form(assigns) do
    ~H"""
    <div class="row" style="padding-top: 5vh;">
      <div class="col-sm-12 col-md-10 offset-md-1 col-lg-8 offset-lg-2 col-xl-6 offset-xl-3 col-xxl-4 offset-xxl-4">
        <div class="card mb-3">
          <div class="card-header">
            <h3>
              <img
                src="/images/logo/logo_favicon.png"
                height="42"
                style="margin-right: 5px;"
                class="d-inline align-top"
              />
              <span>
                Give accolade to user: {@recipient.name}
              </span>
            </h3>
          </div>

          <div :if={@stage == :not_allowed} class="card-body">
            <div class="alert alert-warning">
              {@failure_reason}
            </div>
            <a phx-click="return-to-match" class="btn btn-sm btn-secondary">
              Return to match details
            </a>
          </div>

          <div :if={@stage == :complete} class="card-body">
            You have succesfully gifted an accolade to {@recipient.name}! <br /><br />
            <a phx-click="return-to-match" class="btn btn-sm btn-success">
              Return to match details
            </a>
            <a href={~p"/profile/#{@current_user.id}/accolades"} class="btn btn-sm btn-secondary">
              <i class="fa-solid fa-award"></i> &nbsp;
              View your accolades
            </a>
            <a href={~p"/profile/#{@recipient.id}/accolades"} class="btn btn-sm  btn-secondary">
              <i class="fa-solid fa-award"></i> &nbsp;
              View {@recipient.name}'s accolades
            </a>
          </div>

          <div :if={@stage == :form} class="card-footer">
            You can give this player an accolade if you feel they deserve to be acknowledged for their positive behaviour in this match. You can give {@gift_limit} accolades in a rolling {@gift_window}-day window.
            (You have given {@gift_count} accolades over the past {@gift_window} days.) <br /><br />

            <table class="table table-sm">
              <thead>
                <tr>
                  <th colspan="1"></th>
                  <th colspan="1">Accolade Type</th>
                  <th colspan="2">&nbsp;</th>
                </tr>
              </thead>
              <tbody>
                <%= for badge_type <- @badge_types do %>
                  <tr>
                    <td style={"background-color: #{badge_type.colour}; color: #FFF;"} width="22">
                      {central_component("icon", icon: badge_type.icon)}
                    </td>
                    <td style={"background-color: #{rgba_css badge_type.colour};"}>
                      {badge_type.name}
                    </td>

                    <td>
                      <a
                        phx-click="give-accolade-submit"
                        phx-value-badgeid={badge_type.id}
                        class="btn btn-secondary btn-sm"
                      >
                        Give
                      </a>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <a phx-click="return-to-match" class="btn btn-sm btn-secondary">
              Cancel
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
