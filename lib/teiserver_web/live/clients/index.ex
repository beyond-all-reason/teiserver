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
    users = clients
      |> Map.new(fn c -> {c.userid, User.get_user_by_id(c.userid)} end)

    socket =
      socket
      |> AuthPlug.live_call(session)
      |> NotificationPlug.live_call()
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
      |> add_breadcrumb(name: "Clients", url: "/teiserver/admin/clients")
      |> assign(:sidemenu_active, "teiserver")
      |> assign(:colours, ClientLib.colours())
      |> assign(:clients, clients)
      |> assign(:users, users)

    {:ok, socket, layout: {CentralWeb.LayoutView, "bar_live.html"}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info({:logged_in_client, userid, _username}, socket) do
    keys = socket.assigns[:clients]
      |> Enum.map(fn c -> c.userid end)

    if Enum.member?(keys, userid) do
      {:noreply, socket}
    else
      clients = socket.assigns[:clients] ++ [Client.get_client_by_id(userid)]
      users = Map.put(socket.assigns[:users], userid, User.get_user_by_id(userid))
      
      socket = socket
        |> assign(:clients, clients)
        |> assign(:users, users)

      {:noreply, socket}
    end
  end

  def handle_info({:logged_out_client, userid, _username}, socket) do
    clients = socket.assigns[:clients]
      |> Enum.filter(fn c -> c.userid != userid end)
    users = Map.delete(socket.assigns[:users], userid)

    socket = socket
      |> assign(:clients, clients)
      |> assign(:users, users)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    :ok = PubSub.subscribe(Central.PubSub, "all_client_updates")

    socket
    |> assign(:page_title, "Listing Clients")
    |> assign(:client, nil)
  end

  defp list_clients do
    Client.list_clients()
  end
end
