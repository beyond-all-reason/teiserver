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
      <i class="fas fa-fw fa-swords"></i>
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
      |> assign(:sidemenu_active, "teiserver")
      |> assign(:colours, UserLib.colours())
      |> assign(:extra_menu_content, @extra_menu_content)

    {:ok, socket, layout: {CentralWeb.LayoutView, "nomenu_live.html"}}
  end

  @impl true
  def handle_params(%{"id" => id}, _opts, socket) do
    case allow?(socket.assigns[:current_user], "teiserver.moderator.account") do
      true ->
        id = int_parse(id)
        PubSub.subscribe(Central.PubSub, "legacy_all_user_updates")
        PubSub.subscribe(Central.PubSub, "legacy_all_client_updates")
        PubSub.subscribe(Central.PubSub, "legacy_user_updates:#{id}")
        client = Client.get_client_by_id(id)
        user = User.get_user_by_id(id)

        case client do
          nil ->
            {:noreply,
            socket
            |> redirect(to: Routes.ts_admin_client_index_path(socket, :index))}

          _ ->
            {:noreply,
            socket
            |> assign(:page_title, page_title(socket.assigns.live_action))
            |> add_breadcrumb(name: client.name, url: "/teiserver/admin/clients/#{id}")
            |> assign(:id, id)
            |> assign(:client, client)
            |> assign(:user, user)}
        end
      false ->
        {:noreply,
         socket
         |> redirect(to: Routes.general_page_path(socket, :index))}
    end
  end

  @impl true
  def handle_info({:updated_client, new_client, _reason}, socket) do
    new_client = Client.get_client_by_id(new_client.userid)
    {:noreply, assign(socket, :client, new_client)}
  end

  def handle_info({:user_in, _name}, socket) do
    {:noreply, socket}
  end

  def handle_info({:user_logged_in, _id}, socket) do
    {:noreply, socket}
  end

  def handle_info({:user_logged_out, client_id, _name}, socket) do
    if int_parse(client_id) == socket.assigns[:id] do
      {:noreply,
       socket
       |> redirect(to: Routes.ts_admin_client_index_path(socket, :index))}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:direct_message, _, _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("force-disconnect", _event, socket) do
    Client.disconnect(socket.assigns[:id], "force-disconnect from web")
    {:noreply, socket}
  end

  defp page_title(:show), do: "Show Client"
end
