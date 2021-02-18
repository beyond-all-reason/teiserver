defmodule TeiserverWeb.BattleLive.Show do
  use TeiserverWeb, :live_view

  alias Teiserver.User
  alias Teiserver.Battle
  alias Teiserver.Client

  @impl true
  def mount(_params, session, socket) do
    socket = socket
    |> AuthPlug.live_call(session)
    |> NotificationPlug.live_call
    |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
    |> add_breadcrumb(name: "Battles", url: "/teiserver/battles")
    |> assign(:sidemenu_active, "teiserver")
    |> assign(:colours, Central.Helpers.StylingHelper.colours(:primary2))

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    battle = Battle.get_battle!(id)
    users = User.get_users(battle.players)
      |> Map.new(fn u -> {u.id, u} end)
    clients = Client.get_clients(battle.players)
      |> Map.new(fn c -> {c.userid, c} end)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> add_breadcrumb(name: battle.name, url: "/teiserver/battles/#{battle.id}")
     |> assign(:battle, battle)
     |> assign(:users, users)
     |> assign(:clients, clients)}
  end

  defp page_title(:show), do: "Show Battle"
end
