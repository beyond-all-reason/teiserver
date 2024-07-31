defmodule TeiserverWeb.Battle.MatchLive.Show do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.{Battle, Game, Telemetry}
  alias Teiserver.Battle.{MatchLib, BalanceLib}

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

      rating_logs =
        Game.list_rating_logs(
          search: [
            match_id: match.id
          ]
        )
        |> Map.new(fn log -> {log.user_id, log} end)

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
        BalanceLib.create_balance(groups, match.team_count, algorithm: algorithm)
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

      socket
      |> assign(:match, match)
      |> assign(:match_name, match_name)
      |> assign(:members, members)
      |> assign(:rating_logs, rating_logs)
      |> assign(:parties, parties)
      |> assign(:past_balance, past_balance)
      |> assign(:new_balance, new_balance)
      |> assign(:events_by_type, events_by_type)
      |> assign(:events_by_team_and_type, events_by_team_and_type)
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
    end
  end

  defp generate_new_balance_data(match, algorithm) do
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
            %{userid => BalanceLib.get_user_rating_rank(userid, rating_type)}
          end)

        {_party_id, player_id_list} ->
          player_id_list
          |> Map.new(fn userid ->
            {userid, BalanceLib.get_user_rating_rank(userid, rating_type)}
          end)
      end)
      |> List.flatten()

    BalanceLib.create_balance(groups, match.team_count, algorithm: algorithm)
    |> Map.put(:balance_mode, :grouped)
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
