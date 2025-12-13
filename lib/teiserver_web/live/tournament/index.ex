defmodule TeiserverWeb.TournamentLive.Index do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub

  alias Teiserver
  alias Teiserver.{Battle, Account, Lobby}

  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)

    client = Account.get_client_by_id(socket.assigns[:current_user].id)

    can_join =
      Teiserver.CacheUser.has_any_role?(socket.assigns[:current_user].id, [
        "Moderator",
        "Caster",
        "TourneyPlayer",
        "Tournament player"
      ])

    socket =
      socket
      |> add_breadcrumb(name: "Tournament lobbies", url: ~p"/tournament/lobbies")
      |> assign(:client, client)
      |> assign(:can_join, can_join)
      |> assign(:site_menu_active, "tournaments")
      |> assign(:view_colour, Lobby.colours())
      |> get_lobbies()

    {:ok, socket}
  end

  @impl true
  def handle_params(_, _, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, socket |> redirect(to: ~p"/")}
  end

  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info(
        %{
          channel: "teiserver_liveview_lobby_index_updates",
          event: :updated_data
        },
        socket
      ) do
    {:noreply, socket |> get_lobbies()}
  end

  # Client action
  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :connected}, socket) do
    {:noreply,
     socket
     |> assign(:client, Account.get_client_by_id(socket.assigns[:current_user].id))}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :disconnected}, socket) do
    {:noreply,
     socket
     |> assign(:client, nil)}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("join", _, %{assigns: %{client: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("join", %{"lobby_id" => lobby_id}, %{assigns: assigns} = socket) do
    lobby_id = int_parse(lobby_id)

    if Battle.server_allows_join?(assigns.client.userid, lobby_id) == true do
      Battle.force_add_user_to_lobby(assigns.current_user.id, lobby_id)
    end

    {:noreply, socket}
  end

  defp get_lobbies(socket) do
    lobbies =
      Battle.list_throttled_lobbies(:tournament)
      |> Enum.sort_by(
        fn v -> v.name end,
        &<=/2
      )

    total_members = lobbies |> Enum.reduce(0, fn b, acc -> acc + b.member_count end)
    total_players = lobbies |> Enum.reduce(0, fn b, acc -> acc + b.player_count end)

    stats = %{
      lobby_count: Enum.count(lobbies),
      total_members: total_members,
      total_players: total_players,
      total_spectators: total_members - total_players
    }

    socket
    |> assign(:lobbies, lobbies)
    |> assign(:stats, stats)
  end

  defp apply_action(socket, :index, _params) do
    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_liveview_lobby_index_updates")

    :ok =
      PubSub.subscribe(
        Teiserver.PubSub,
        "teiserver_client_messages:#{socket.assigns[:current_user].id}"
      )

    socket
    |> assign(:page_title, "Tournament lobbies")
  end
end
