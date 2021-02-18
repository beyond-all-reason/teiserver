defmodule TeiserverWeb.AdminLive.Index do
  use TeiserverWeb, :live_view

  alias Central.Account.User
  alias Teiserver.Account
  alias Teiserver.Account.UserLib

  @impl true
  def mount(params, session, socket) do
    socket = socket
    |> AuthPlug.live_call(session)
    |> NotificationPlug.live_call
    |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
    |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
    |> assign(:sidemenu_active, "teiserver")
    |> assign(:colours, UserLib.colours())

    users = Account.list_users(
      search: [
        admin_group: socket,
        simple_search: Map.get(params, "s", "") |> String.trim,
      ],
      order_by: "Name (A-Z)"
    )
    |> Enum.filter(fn u -> u.admin_group != nil end)
    
    socket = socket
    |> assign(:users, users)

    {:ok, socket, layout: {CentralWeb.LayoutView, "bar_live.html"}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit User")
    |> assign(:user, Account.get_user!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New User")
    |> assign(:user, %User{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Users")
    |> assign(:user, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Account.get_user!(id)
    {:ok, _} = Account.delete_user(user)

    {:noreply, assign(socket, :users, list_users())}
  end

  defp list_users do
    Account.list_users()
  end
end
