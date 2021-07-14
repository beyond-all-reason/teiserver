defmodule TeiserverWeb.ClientLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub

  alias Teiserver
  alias Teiserver.User
  alias Teiserver.Client
  alias Teiserver.ClientLib

  @extra_menu_content """
  &nbsp;&nbsp;&nbsp;
    <a href='/teiserver/battle/lobbies' class="btn btn-outline-primary">
      <i class="fas fa-fw fa-swords"></i>
      Battles
    </a>
  """

  @impl true
  def mount(_params, session, socket) do
    clients = list_clients()
      |> Map.new(fn c -> {c.userid, c} end)

    users =
      clients
      |> Map.new(fn {userid, _} -> {userid, User.get_user_by_id(userid)} end)

    socket =
      socket
      |> AuthPlug.live_call(session)
      |> NotificationPlug.live_call()
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
      |> add_breadcrumb(name: "Clients", url: "/teiserver/admin/client")
      |> assign(:sidemenu_active, "teiserver")
      |> assign(:colours, ClientLib.colours())
      |> assign(:clients, clients)
      |> assign(:client_ids, Map.keys(clients))
      |> assign(:users, users)
      |> assign(:menu_override, :hidden)
      |> assign(:extra_menu_content, @extra_menu_content)
      |> assign(:filters, [])
      |> apply_filters

    {:ok, socket, layout: {CentralWeb.LayoutView, "blank_live.html"}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case allow?(socket.assigns[:current_user], "teiserver.moderator.account") do
      true ->
        {:noreply, apply_action(socket, socket.assigns.live_action, params)}
      false ->
        {:noreply,
         socket
         |> redirect(to: Routes.general_page_path(socket, :index))}
    end
  end

  @impl true
  def handle_info({:client_index_throttle, new_clients, removed_clients}, %{assigns: assigns} = socket) do
    clients = assigns.clients
      |> Enum.filter(fn {userid, _} ->
        not Enum.member?(removed_clients, userid)
      end)
      |> Map.new
      |> Map.merge(new_clients)

    client_ids = Map.keys(clients)

    users = client_ids
      |> Enum.map(fn userid ->
        if Map.has_key?(assigns.users, userid) do
          assigns.users[userid]
        else
          User.get_user_by_id(userid)
          |> limited_user
        end
      end)
      |> Map.new(fn user -> {user.id, user} end)

    socket = socket
      |> assign(:clients, clients)
      |> assign(:users, users)
      |> apply_filters

    {:noreply, socket}
  end

  @impl true
  def handle_event("add-filter:" <> filter, _event, socket) do
    new_filters = [filter | socket.assigns.filters]
      |> Enum.uniq

    {:noreply, assign(socket, :filters, new_filters) |> apply_filters}
  end

  def handle_event("remove-filter:" <> filter, _event, socket) do
    new_filters = socket.assigns.filters
      |> List.delete(filter)

    {:noreply, assign(socket, :filters, new_filters) |> apply_filters}
  end

  defp apply_action(socket, :index, _params) do
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_liveview_client_index_updates")

    socket
    |> assign(:page_title, "Listing Clients")
    |> assign(:client, nil)
  end

  defp list_clients do
    Client.list_clients()
    |> Enum.sort_by(fn c -> c.name end, &<=/2)
  end

  defp apply_filters(%{assigns: assigns} = socket) do
    filters = assigns.filters

    client_ids = assigns.clients
      |> Enum.filter(fn {_userid, client} ->
        cond do
          Enum.member?(filters, "people") and client.bot ->
            false

          Enum.member?(filters, "normal") and client.moderator ->
            false

          true ->
            true
        end
      end)
      |> Enum.sort_by(fn {_, client} -> String.downcase(client.name) end, &<=/2)
      |> Enum.map(fn {key, _} -> key end)

    socket
      |> assign(:client_ids, client_ids)
  end

  defp limited_user(user) do
    Map.take(user, ~w(id bot moderator verified)a)
  end
end
