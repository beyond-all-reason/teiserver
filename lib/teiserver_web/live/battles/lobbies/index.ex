defmodule TeiserverWeb.Battle.LobbyLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub

  alias Teiserver
  alias Teiserver.{Battle, Lobby, Account}

  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)

    moderator = allow?(socket.assigns[:current_user], "Moderator")

    socket =
      socket
      |> assign(:moderator, moderator)

    disabled? = Teiserver.Config.get_site_config_cache("lobby.Disable lobby live view on website")

    socket =
      socket
      |> populate_initial_assigns()
      |> add_breadcrumb(name: "Battles", url: "/battle/lobbies")
      |> assign(:site_menu_active, "lobbies")
      |> assign(:view_colour, Lobby.colours())
      |> assign(:disabled?, disabled?)

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
  def handle_info(%{channel: "teiserver_global_lobby_updates"}, socket)
      when socket.assigns.disabled?,
      do: {:noreply, socket}

  def handle_info(%{channel: "teiserver_client_messages:" <> _}, socket)
      when socket.assigns.disabled?,
      do: {:noreply, socket}

  def handle_info(
        %{
          channel: "teiserver_global_lobby_updates",
          event: :opened,
          lobby: lobby
        },
        socket
      ) do
    lobbies =
      [lobby | socket.assigns[:lobbies]]
      |> filter_lobbies(socket)
      |> sort_lobbies()

    {:noreply, assign(socket, :lobbies, lobbies)}
  end

  def handle_info(
        %{
          channel: "teiserver_global_lobby_updates",
          event: :closed,
          lobby_id: lobby_id
        },
        socket
      ) do
    lobbies =
      socket.assigns[:lobbies]
      |> Enum.filter(fn b -> b.id != lobby_id end)
      |> filter_lobbies(socket)
      |> sort_lobbies()

    {:noreply, assign(socket, :lobbies, lobbies)}
  end

  def handle_info(
        %{
          channel: "teiserver_global_lobby_updates",
          event: :updated_values,
          lobby_id: lobby_id,
          new_values: new_values
        },
        socket
      ) do
    lobbies =
      socket.assigns[:lobbies]
      |> Enum.map(fn l ->
        if l.id == lobby_id do
          Map.merge(l, new_values)
        else
          l
        end
      end)
      |> filter_lobbies(socket)
      |> sort_lobbies()

    {:noreply, assign(socket, :lobbies, lobbies)}
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

  def handle_info(
        %{
          channel: "teiserver_lobby_web",
          event: :update_live_lobby_feature,
          disabled?: disabled?
        },
        socket
      ) do
    socket = assign(socket, :disabled?, disabled?)

    if disabled? do
      unsubscribe_topics(socket.assigns[:current_user].id)
      socket = socket |> assign(:lobbies, []) |> assign(:client, nil)
      {:noreply, socket}
    else
      subscribe_topics(socket.assigns[:current_user].id)
      {:noreply, populate_initial_assigns(socket)}
    end
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

  defp filter_lobbies(lobbies, %{assigns: %{moderator: moderator}} = _socket) do
    if moderator do
      lobbies
      |> Enum.reject(fn lobby ->
        lobby.tournament
      end)
    else
      lobbies
      |> Enum.reject(fn lobby ->
        lobby.locked or
          lobby.passworded or
          lobby.tournament
      end)
    end
  end

  defp sort_lobbies(lobbies) do
    lobbies
    |> Enum.sort_by(
      fn v -> {v.locked, v.passworded, -v.member_count, v.name} end,
      &<=/2
    )
  end

  defp apply_action(socket, :index, _params) do
    subscribe_topics(socket.assigns[:current_user].id)
    PubSub.subscribe(Teiserver.PubSub, "teiserver_lobby_web")

    socket
    |> assign(:page_title, "Listing Battles")
    |> assign(:battle, nil)
  end

  defp subscribe_topics(user_id) do
    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_global_lobby_updates")

    :ok =
      PubSub.subscribe(
        Teiserver.PubSub,
        "teiserver_client_messages:#{user_id}"
      )
  end

  defp unsubscribe_topics(user_id) do
    :ok = PubSub.unsubscribe(Teiserver.PubSub, "teiserver_global_lobby_updates")

    :ok =
      PubSub.unsubscribe(
        Teiserver.PubSub,
        "teiserver_client_messages:#{user_id}"
      )
  end

  defp populate_initial_assigns(socket) do
    client = Account.get_client_by_id(socket.assigns[:current_user].id)

    lobbies =
      Lobby.list_lobbies()
      |> Enum.map(fn lobby ->
        Map.merge(lobby, %{
          member_count: Battle.get_lobby_member_count(lobby.id),
          player_count: Battle.get_lobby_player_count(lobby.id),
          uuid: Battle.get_lobby_match_uuid(lobby.id)
        })
      end)
      |> filter_lobbies(socket)
      |> sort_lobbies()

    socket
    |> assign(:lobbies, lobbies)
    |> assign(:client, client)
  end
end
