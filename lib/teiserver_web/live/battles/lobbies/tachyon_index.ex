defmodule TeiserverWeb.Battle.LobbyLive.TachyonIndex do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub

  alias Teiserver.TachyonLobby
  alias Teiserver
  alias Teiserver.{Battle, Lobby, Account}

  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  @impl true
  @spec mount(any(), nil | maybe_improper_list() | map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, map()}
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)

    # TODO fix this correctly
    _contributor = allow?(socket.assigns[:current_user], "Contributor")
    contributor = true

    # TODO move this to the top of the mount section
    disabled? = Teiserver.Config.get_site_config_cache("lobby.Disable lobby live view on website")

    {counter, lobbies} = TachyonLobby.subscribe_updates()
    lobby_list = lobbies |> Map.values()

    socket =
      socket
      |> populate_initial_assigns()
      |> add_breadcrumb(name: "Tachyon Battles", url: "/battle/tachyon_lobbies")
      |> assign(:site_menu_active, "lobbies")
      |> assign(:view_colour, Lobby.colours())
      |> assign(:disabled?, disabled?)
      |> assign(:contributor, contributor)
      |> assign(:lobbies, lobby_list)
      |> assign(:counter, counter)

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
  def handle_info(%{channel: "teiserver_tachyonlobby_list"}, socket)
      when socket.assigns.disabled?,
      do: {:noreply, socket}

  def handle_info(%{channel: "teiserver_client_messages:" <> _}, socket)
      when socket.assigns.disabled?,
      do: {:noreply, socket}

  def handle_info(
        %{
          channel: "teiserver_tachyonlobby_list",
          event: :opened,
          lobby: lobby
        },
        socket
      ) do
    lobbies =
      [lobby | socket.assigns[:lobbies]]
      |> sort_lobbies()

    {:noreply, assign(socket, :lobbies, lobbies)}
  end

  def handle_info(
        %{
          channel: "teiserver_tachyonlobby_list",
          event: :closed,
          lobby_id: lobby_id
        },
        socket
      ) do
    lobbies =
      socket.assigns[:lobbies]
      |> Enum.filter(fn b -> b.id != lobby_id end)
      |> sort_lobbies()

    {:noreply, assign(socket, :lobbies, lobbies)}
  end

  def handle_info(
        %{
          channel: "teiserver_tachyonlobby_list",
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

  defp sort_lobbies(lobbies) do
    lobbies
    |> Enum.sort_by(
      fn {_, v} -> {-v.player_count, v.name} end,
      &<=/2
    )
  end

  defp apply_action(socket, :index, _params) do
    subscribe_topics(socket.assigns[:current_user].id)
    # required to monitor if live_lobby_listing is disabled
    PubSub.subscribe(Teiserver.PubSub, "teiserver_lobby_web")

    socket
    |> assign(:page_title, "Listing Tachyon Battles")
    |> assign(:battle, nil)
  end

  defp subscribe_topics(user_id) do
    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_tachyonlobby_list")

    :ok =
      PubSub.subscribe(
        Teiserver.PubSub,
        "teiserver_client_messages:#{user_id}"
      )
  end

  defp unsubscribe_topics(user_id) do
    :ok = PubSub.unsubscribe(Teiserver.PubSub, "teiserver_tachyonlobby_list")

    :ok =
      PubSub.unsubscribe(
        Teiserver.PubSub,
        "teiserver_client_messages:#{user_id}"
      )
  end

  defp populate_initial_assigns(socket) do
    client = Account.get_client_by_id(socket.assigns[:current_user].id)

    # TODO determine how to use these _counter
    lobbies =
      Teiserver.TachyonLobby.List.list()
      |> sort_lobbies()

    socket
    |> assign(:lobbies, lobbies)
    |> assign(:client, client)
  end
end
