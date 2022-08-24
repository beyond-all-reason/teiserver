defmodule TeiserverWeb.Account.PartyLive.Show do
  use TeiserverWeb, :live_view
  # alias Phoenix.PubSub
  require Logger

  alias Teiserver.Account
  alias Teiserver.Account.PartyLib

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
        |> AuthPlug.live_call(session)
        |> TSAuthPlug.live_call(session)
        |> NotificationPlug.live_call()

    client = Account.get_client_by_id(socket.assigns.user_id)

    socket = socket
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Parties", url: "/teiserver/account/parties")
      |> add_breadcrumb(name: "Parties", url: "/teiserver/account/parties")
      |> assign(:client, client)
      |> assign(:site_menu_active, "parties")
      |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))
      |> assign(:view_colour, PartyLib.colours())
      |> assign(:user_lookup, %{})
      # |> build_user_lookup()

    {:ok, socket}
  end

  @impl true
  def handle_params(_, _, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, socket |> redirect(to: Routes.general_page_path(socket, :index))}
  end

  def handle_params(%{"id" => party_id}, _, socket) do
    party = Account.get_party(party_id)

    if party do
      {:noreply,
        socket
        |> assign(:party_id, party_id)
        |> assign(:party, party)
      }
    else
      {:noreply, socket |> redirect(to: Routes.ts_game_party_index_path(socket, :index))}
    end
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(TeiserverWeb.Account.PartyLiveView, "show.html", assigns)
  end

  def build_user_lookup(socket) do
    existing_user_ids = Map.keys(socket.assigns.user_lookup)

    new_users = socket.assigns.parties
      |> Enum.map(fn p -> p.members end)
      |> List.flatten
      |> Enum.reject(fn m -> Enum.member?(existing_user_ids, m) end)
      |> Account.list_users_from_cache
      |> Map.new(fn u -> {u.id, u} end)

    new_user_lookup = Map.merge(socket.assigns.user_lookup, new_users)

    socket
      |> assign(:user_lookup, new_user_lookup)
  end
end
