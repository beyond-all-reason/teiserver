defmodule TeiserverWeb.ClientLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub

  alias Teiserver
  alias Teiserver.User
  alias Teiserver.Client
  alias Teiserver.ClientLib

  @impl true
  def mount(_params, session, socket) do
    clients = list_clients()

    users =
      clients
      |> Map.new(fn c -> {c.userid, User.get_user_by_id(c.userid)} end)

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
      |> assign(:users, users)
      |> assign(:menu_override, Routes.ts_lobby_general_path(socket, :index))

    {:ok, socket, layout: {CentralWeb.LayoutView, "blank_live.html"}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case allow?(socket.assigns[:current_user], "teiserver.admin.account") do
      true ->
        {:noreply, apply_action(socket, socket.assigns.live_action, params)}
      false ->
        {:noreply,
         socket
         |> redirect(to: Routes.general_page_path(socket, :index))}
    end
  end

  @impl true
  def handle_info({:user_logged_in, userid}, socket) do
    keys =
      socket.assigns[:clients]
      |> Enum.map(fn c -> c.userid end)

    if Enum.member?(keys, userid) do
      {:noreply, socket}
    else
      clients =
        (socket.assigns[:clients] ++ [Client.get_client_by_id(userid)])
        |> Enum.sort_by(fn c -> c.name end, &<=/2)

      users = Map.put(socket.assigns[:users], userid, User.get_user_by_id(userid))

      socket =
        socket
        |> assign(:clients, clients)
        |> assign(:users, users)

      {:noreply, socket}
    end
  end

  def handle_info({:user_logged_out, userid, _username}, socket) do
    clients =
      socket.assigns[:clients]
      |> Enum.filter(fn c -> c.userid != userid end)

    users = Map.delete(socket.assigns[:users], userid)

    socket =
      socket
      |> assign(:clients, clients)
      |> assign(:users, users)

    {:noreply, socket}
  end

  def handle_info({:updated_client, _new_client, _reason}, socket) do
    # clients = socket.assigns[:clients]
    #   |> Enum.filter(fn c -> c.userid != userid end)
    # users = Map.delete(socket.assigns[:users], userid)

    # socket = socket
    #   |> assign(:clients, clients)
    #   |> assign(:users, users)

    {:noreply, socket}
  end

  def handle_info({:add_user_to_battle, user_id, battle_id, _script_password}, socket) do
    clients =
      socket.assigns[:clients]
      |> Enum.map(fn client ->
        if client.userid == user_id do
          %{client | battle_id: battle_id}
        else
          client
        end
      end)

    {:noreply, assign(socket, :clients, clients)}
  end

  def handle_info({:remove_user_from_battle, user_id, _battle_id}, socket) do
    clients =
      socket.assigns[:clients]
      |> Enum.map(fn client ->
        if client.userid == user_id do
          %{client | battle_id: nil}
        else
          client
        end
      end)

    {:noreply, assign(socket, :clients, clients)}
  end

  def handle_info({:kick_user_from_battle, user_id, _battle_id}, socket) do
    clients =
      socket.assigns[:clients]
      |> Enum.map(fn client ->
        if client.userid == user_id do
          %{client | battle_id: nil}
        else
          client
        end
      end)

    {:noreply, assign(socket, :clients, clients)}
  end

  def handle_info({:battle_opened, _battle_id}, socket) do
    {:noreply, socket}
  end

  def handle_info({:battle_closed, _battle_id}, socket) do
    {:noreply, socket}
  end

  def handle_info({:global_battle_updated, _battle_id, _reason}, socket) do
    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    :ok = PubSub.subscribe(Central.PubSub, "all_user_updates")
    :ok = PubSub.subscribe(Central.PubSub, "all_client_updates")
    :ok = PubSub.subscribe(Central.PubSub, "all_battle_updates")

    socket
    |> assign(:page_title, "Listing Clients")
    |> assign(:client, nil)
  end

  defp list_clients do
    Client.list_clients()
    |> Enum.sort_by(fn c -> c.name end, &<=/2)
  end
end
