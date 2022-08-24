defmodule TeiserverWeb.Account.PartyLive.Index do
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
    mode = case params["mode"] do
      "admin" -> "admin"
      _ -> "player"
    end

    socket = socket
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Parties", url: "/teiserver/account/parties")
      |> assign(:mode, mode)
      |> assign(:client, client)
      |> assign(:site_menu_active, "parties")
      |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))
      |> assign(:view_colour, PartyLib.colours())
      |> assign(:user_lookup, %{})
      |> list_parties()
      |> build_user_lookup()

    {:ok, socket}
  end

  @impl true
  def handle_params(_, _, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, socket |> redirect(to: Routes.general_page_path(socket, :index))}
  end

  def handle_params(_, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(TeiserverWeb.Account.PartyLiveView, "index.html", assigns)
  end

  defp list_parties(%{assigns: %{mode: "admin"}} = socket) do
    parties = Account.list_party_ids()
      |> Account.list_parties()

    socket
      |> assign(:parties, parties)
  end

  defp list_parties(socket) do
    parties = Account.get_user_by_id(socket.assigns.user_id)
      |> Enum.map(fn user_id ->
        Account.get_client_by_id(user_id)
      end)
      |> Enum.reject(&(&1 == nil))
      |> Enum.map(fn c -> c.party_id end)
      |> Enum.reject(&(&1 == nil))
      |> Enum.uniq
      |> Account.list_parties()

    socket
      |> assign(:parties, parties)
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
