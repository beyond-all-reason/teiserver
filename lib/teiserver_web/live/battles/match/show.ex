defmodule BarserverWeb.Battle.MatchLive.Show do
  @moduledoc false
  use BarserverWeb, :live_view
  alias Barserver.{Battle, Game}
  alias Barserver.Battle.MatchLib

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:site_menu_active, "match")
      |> assign(:view_colour, Barserver.Battle.MatchLib.colours())
      |> assign(:tab, "details")

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
    |> mount_require_any(["Reviewer"])
    |> assign(:page_title, "#{match_name} - Ratings")
  end

  defp apply_action(%{assigns: %{match_name: match_name}} = socket, :balance, _params) do
    socket
    |> mount_require_any(["Reviewer"])
    |> assign(:page_title, "#{match_name} - Balance")
  end

  # @impl true
  # def handle_event("tab-select", %{"tab" => tab}, socket) do
  #   {:noreply, assign(socket, :tab, tab)}
  # end

  defp get_match(%{assigns: %{id: id, current_user: _current_user}} = socket) do
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
        |> Enum.zip(Barserver.Helper.StylingHelper.bright_hex_colour_list())
        |> Enum.zip(~w(dice-one dice-two dice-three dice-four dice-five dice-six))
        |> Enum.map(fn {{party_id, colour}, idx} ->
          {party_id, {colour, idx}}
        end)
        |> Map.new()

      socket
      |> assign(:match, match)
      |> assign(:match_name, match_name)
      |> assign(:members, members)
      |> assign(:rating_logs, rating_logs)
      |> assign(:parties, parties)
    else
      socket
      |> assign(:match, nil)
      |> assign(:match_name, "Loading...")
      |> assign(:members, [])
      |> assign(:rating_logs, [])
      |> assign(:parties, %{})
    end
  end
end
