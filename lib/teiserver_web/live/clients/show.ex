defmodule TeiserverWeb.ClientLive.Show do
  alias Phoenix.PubSub
  alias Teiserver.Account
  alias Teiserver.Account.UserLib
  alias Teiserver.Battle
  alias Teiserver.CacheUser
  alias Teiserver.Client
  use TeiserverWeb, :live_view
  require Logger
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  @extra_menu_content """
  &nbsp;&nbsp;&nbsp;
    <a href='/battle/lobbies' class="btn btn-outline-primary">
      <i class="fa-solid fa-fw fa-swords"></i>
      Battles
    </a>
  """

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)

    current_client = Account.get_client_by_id(socket.assigns[:current_user].id)

    :ok =
      PubSub.subscribe(
        Teiserver.PubSub,
        "teiserver_client_messages:#{socket.assigns[:current_user].id}"
      )

    socket =
      socket
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
      |> add_breadcrumb(name: "Clients", url: "/teiserver/admin/client")
      |> assign(:current_client, current_client)
      |> assign(:site_menu_active, "teiserver_user")
      |> assign(:view_colour, UserLib.colours())
      |> assign(:extra_menu_content, @extra_menu_content)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _opts, socket) do
    case allow?(socket.assigns[:current_user], "Moderator") do
      true ->
        id = int_parse(id)
        PubSub.subscribe(Teiserver.PubSub, "teiserver_client_watch:#{id}")
        client = Account.get_client_by_id(id)
        user = CacheUser.get_user_by_id(id)

        connection_state =
          cond do
            client == nil ->
              %{}

            Process.alive?(client.tcp_pid) == true ->
              :sys.get_state(client.tcp_pid)

            true ->
              %{}
          end

        # If viewing an internal server process you it won't have these keys and thus we use
        # this method
        server_debug_messages = Map.get(connection_state, :print_server_messages, false)
        client_debug_messages = Map.get(connection_state, :print_client_messages, false)

        if client && user do
          {:noreply,
           socket
           |> assign(:page_title, page_title(socket.assigns.live_action))
           |> add_breadcrumb(name: user.name, url: ~p"/teiserver/admin/client/#{id}")
           |> assign(:id, id)
           |> assign(:client, client)
           |> assign(:user, user)
           |> assign(:client_debug_messages, client_debug_messages)
           |> assign(:server_debug_messages, server_debug_messages)}
        else
          {:noreply,
           socket
           |> redirect(to: ~p"/teiserver/admin/client")}
        end

      false ->
        {:noreply,
         socket
         |> redirect(to: ~p"/")}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:updated_client, new_client, _reason}, socket) do
    if new_client.userid == socket.assigns.id do
      new_client = Account.get_client_by_id(new_client.userid)
      {:noreply, assign(socket, :client, new_client)}
    else
      {:noreply, socket}
    end
  end

  # Watched client
  def handle_info(%{channel: "teiserver_client_watch:" <> _client_id, event: :connected}, socket) do
    client = Account.get_client_by_id(socket.assigns.id)

    {:noreply,
     socket
     |> assign(:client, client)}
  end

  def handle_info(
        %{channel: "teiserver_client_watch:" <> _client_id, event: :disconnected},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:client, nil)}
  end

  def handle_info(
        %{channel: "teiserver_client_watch:" <> _client_id, event: :added_to_lobby},
        socket
      ) do
    client = Account.get_client_by_id(socket.assigns.id)

    {:noreply,
     socket
     |> assign(:client, client)}
  end

  def handle_info(%{channel: "teiserver_client_watch:" <> _client_id, event: :left_lobby}, socket) do
    client = Account.get_client_by_id(socket.assigns.id)

    {:noreply,
     socket
     |> assign(:client, client)}
  end

  def handle_info(%{channel: "teiserver_client_watch:" <> _rest}, socket) do
    {:noreply, socket}
  end

  # Our client
  def handle_info(%{channel: "teiserver_client_messages:" <> _user_id, event: :connected}, socket) do
    {:noreply,
     socket
     |> assign(:current_client, Account.get_client_by_id(socket.assigns.current_user.id))}
  end

  def handle_info(
        %{channel: "teiserver_client_messages:" <> _user_id, event: :disconnected},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:current_client, nil)}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _rest}, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("enable-server-message-logging", _event, socket) do
    Client.enable_server_message_print(socket.assigns.id)

    {:noreply,
     socket
     |> assign(:server_debug_messages, true)}
  end

  def handle_event("disable-server-message-logging", _event, socket) do
    Client.disable_server_message_print(socket.assigns.id)

    {:noreply,
     socket
     |> assign(:server_debug_messages, false)}
  end

  def handle_event("enable-client-message-logging", _event, socket) do
    Client.enable_client_message_print(socket.assigns.id)

    {:noreply,
     socket
     |> assign(:client_debug_messages, true)}
  end

  def handle_event("disable-client-message-logging", _event, socket) do
    Client.disable_client_message_print(socket.assigns.id)

    {:noreply,
     socket
     |> assign(:client_debug_messages, false)}
  end

  def handle_event("force-error-log", _event, socket) do
    p = Account.get_client_by_id(socket.assigns.id) |> Map.get(:tcp_pid)
    send(p, :error_log)
    {:noreply, socket}
  end

  def handle_event("force-reconnect", _event, socket) do
    Client.disconnect(socket.assigns[:id], "reconnect")
    {:noreply, socket |> redirect(to: ~p"/teiserver/admin/client")}
  end

  def handle_event("force-flood", _event, socket) do
    CacheUser.set_flood_level(socket.assigns[:id], 100)
    Client.disconnect(socket.assigns[:id], "flood protection")
    {:noreply, socket |> redirect(to: ~p"/teiserver/admin/client")}
  end

  # Join battle stuff
  def handle_event("join-lobby", _params, %{assigns: %{current_client: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("join-lobby", _params, %{assigns: assigns} = socket) do
    if Battle.server_allows_join?(assigns.current_client.userid, assigns.client.lobby_id) == true do
      Battle.force_add_user_to_lobby(assigns.current_user.id, assigns.client.lobby_id)
    end

    {:noreply, socket}
  end

  defp page_title(:show), do: "Show Client"
end
