defmodule TeiserverWeb.Account.PartyLive.Index do
  use TeiserverWeb, :live_view
  # alias Phoenix.PubSub
  require Logger

  alias Teiserver.Account.PartyLib

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)
      |> TSAuthPlug.live_call(session)
      |> NotificationPlug.live_call()

    socket = socket
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Parties", url: "/teiserver/account/parties")
      |> assign(:site_menu_active, "parties")
      |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))
      |> assign(:view_colour, PartyLib.colours())

    {:ok, socket}
  end

  # @impl true
  # def handle_params(_, _, %{assigns: %{current_user: nil}} = socket) do
  #   {:noreply, socket |> redirect(to: Routes.general_page_path(socket, :index))}
  # end

  @impl true
  def render(assigns) do
    Phoenix.View.render(TeiserverWeb.Account.PartyLiveView, "index.html", assigns)
  end
end
