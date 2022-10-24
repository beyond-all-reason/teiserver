defmodule TeiserverWeb.ClientLive.Show do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  require Logger

  alias Teiserver.{Client, User}
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Teiserver.Account.UserLib

  @extra_menu_content """
  &nbsp;&nbsp;&nbsp;
    <a href='/teiserver/battle/lobbies' class="btn btn-outline-primary">
      <i class="fa-solid fa-fw fa-swords"></i>
      Battles
    </a>
  """

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)
      |> NotificationPlug.live_call()
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
      |> add_breadcrumb(name: "Clients", url: "/teiserver/admin/client")
      |> assign(:site_menu_active, "teiserver_user")
      |> assign(:view_colour, UserLib.colours())
      |> assign(:extra_menu_content, @extra_menu_content)

    {:ok, socket, layout: {CentralWeb.LayoutView, "standard_live.html"}}
  end

  @impl true
  def handle_params(%{"id" => id}, _opts, socket) do
    case allow?(socket.assigns[:current_user], "teiserver.moderator.account") do
      true ->
        id = int_parse(id)
        PubSub.subscribe(Central.PubSub, "teiserver_client_messages:#{id}")
        client = Client.get_client_by_id(id)
        user = User.get_user_by_id(id)

        case client do
          nil ->
            {
              :noreply,
              socket
                |> redirect(to: Routes.ts_admin_client_index_path(socket, :index))
            }

          _ ->
            connection_state = :sys.get_state(client.tcp_pid)

            server_debug_messages = connection_state.print_server_messages
            client_debug_messages = connection_state.print_client_messages

            {:noreply,
              socket
                |> assign(:page_title, page_title(socket.assigns.live_action))
                |> add_breadcrumb(name: client.name, url: "/teiserver/admin/clients/#{id}")
                |> assign(:id, id)
                |> assign(:client, client)
                |> assign(:user, user)
                |> assign(:client_debug_messages, client_debug_messages)
                |> assign(:server_debug_messages, server_debug_messages)
            }
        end
      false ->
        {:noreply,
         socket
         |> redirect(to: Routes.general_page_path(socket, :index))}
    end
  end

  @impl true
  def handle_info({:updated_client, new_client, _reason}, socket) do
    if new_client.userid == socket.assigns.id do
      new_client = Client.get_client_by_id(new_client.userid)
      {:noreply, assign(socket, :client, new_client)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :disconnected}, socket) do
    {:noreply,
       socket
       |> redirect(to: Routes.ts_admin_client_index_path(socket, :index))}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("enable-server-message-logging", _event, socket) do
    Client.enable_server_message_print(socket.assigns.id)
    {:noreply, socket
      |> assign(:server_debug_messages, true)
    }
  end

  def handle_event("disable-server-message-logging", _event, socket) do
    Client.disable_server_message_print(socket.assigns.id)
    {:noreply, socket
      |> assign(:server_debug_messages, false)
    }
  end

  def handle_event("enable-client-message-logging", _event, socket) do
    Client.enable_client_message_print(socket.assigns.id)
    {:noreply, socket
      |> assign(:client_debug_messages, true)
    }
  end

  def handle_event("disable-client-message-logging", _event, socket) do
    Client.disable_client_message_print(socket.assigns.id)
    {:noreply, socket
      |> assign(:client_debug_messages, false)
    }
  end

  def handle_event("force-error-log", _event, socket) do
    p = Client.get_client_by_id(socket.assigns.id) |> Map.get(:tcp_pid)
    send(p, :error_log)
    {:noreply, socket}
  end

  def handle_event("force-reconnect", _event, socket) do
    Client.disconnect(socket.assigns[:id], "reconnect")
    {:noreply, socket |> redirect(to: Routes.ts_admin_client_index_path(socket, :index))}
  end

  def handle_event("force-flood", _event, socket) do
    User.set_flood_level(socket.assigns[:id], 100)
    Client.disconnect(socket.assigns[:id], "flood protection")
    {:noreply, socket |> redirect(to: Routes.ts_admin_client_index_path(socket, :index))}
  end

  defp page_title(:show), do: "Show Client"
end
