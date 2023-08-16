defmodule TeiserverWeb.Admin.TestPageLive.Index do
  use TeiserverWeb, :live_view

  @default_tab "icons"
  @limited_bsnames ~w(primary success info warning danger)
  @full_bsnames ~w(primary primary2 secondary success success2 info info2 warning warning2 danger danger2)

  @impl true
  def mount(_params, _session, socket) do
    socket = socket
      |> assign(:site_menu_active, "admin")
      |> assign(:view_colour, Central.Admin.AdminLib.colours())
      |> assign(:tab, @default_tab)
      |> assign(:limited_bsnames, @limited_bsnames)
      |> assign(:full_bsnames, @full_bsnames)
      |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
      |> add_breadcrumb(name: "Tools", url: "/teiserver/admin/tools")
      |> add_breadcrumb(name: "Test page", url: "/admin/test_page")

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"tab" => tab} = params, _url, socket) do
    socket = socket
      |> assign(:tab, tab)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(%{assigns: %{tab: "alerts"}} = socket, _, _params) do
    socket
    |> put_flash(:success, "Success flash - #{:rand.uniform(1000)}")
    |> put_flash(:info, "Info flash - #{:rand.uniform(1000)}")
    |> put_flash(:warning, "Warning flash - #{:rand.uniform(1000)}")
    |> put_flash(:error, "Danger/Error flash - #{:rand.uniform(1000)}")
  end

  defp apply_action(socket, _, _params) do
    socket
  end

  @impl true
  def handle_event("create-flash", %{"name" => name}, socket) do
    socket = case name do
      "success" ->
        socket
        |> put_flash(:success, "Success flash - #{:rand.uniform(1000)}")
      "info" ->
        socket
        |> put_flash(:info, "Info flash - #{:rand.uniform(1000)}")
      "warning" ->
        socket
          |> put_flash(:warning, "Warning flash - #{:rand.uniform(1000)}")
      "danger" ->
        socket
          |> put_flash(:error, "Danger/Error flash - #{:rand.uniform(1000)}")
    end

    {:noreply, socket}
  end
end
