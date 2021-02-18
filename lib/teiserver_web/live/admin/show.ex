defmodule TeiserverWeb.AdminLive.Show do
  use TeiserverWeb, :live_view

  alias Central.Account.User
  alias Teiserver.Account
  alias Teiserver.Account.UserLib

  @impl true
  def mount(_params, session, socket) do
    socket = socket
    |> AuthPlug.live_call(session)
    |> NotificationPlug.live_call
    |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
    |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
    |> assign(:sidemenu_active, "teiserver")
    |> assign(:colours, UserLib.colours())

    {:ok, socket, layout: {CentralWeb.LayoutView, "bar_live.html"}}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:user, Account.get_user!(id))}
  end

  defp page_title(:show), do: "Show User"
  defp page_title(:edit), do: "Edit User"
end
