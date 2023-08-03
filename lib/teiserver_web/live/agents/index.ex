defmodule TeiserverWeb.AgentLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub

  alias Teiserver

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)
      |> NotificationPlug.live_call()

    if allow?(socket.assigns[:current_user], "admin.dev.developer") do
      Teiserver.agent_mode()
    end

    socket =
      socket
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
      |> add_breadcrumb(name: "Agents", url: "/teiserver/admin/agent")
      |> assign(:logs, [])
      |> assign(:filtered_logs, [])
      |> assign(:filters, %{})
      |> assign(:sidemenu_active, "teiserver")
      |> assign(:colours, Central.Admin.ToolLib.colours())

    {:ok, socket, layout: {CentralWeb.LayoutView, :standard_live}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case allow?(socket.assigns[:current_user], "admin.dev.developer") do
      true ->
        {:noreply, apply_action(socket, socket.assigns.live_action, params)}

      false ->
        {:noreply,
         socket
         |> redirect(to: ~p"/")}
    end
  end

  @spec handle_info(any, Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  @impl true
  def handle_info(new_log, socket) do
    socket =
      socket
      |> assign(:logs, [new_log] ++ socket.assigns[:logs])
      |> filter_logs()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter-add:" <> filter, _event, socket) do
    [key, value] = String.split(filter, "=")

    filters = socket.assigns[:filters]

    new_filters =
      case key do
        "agent" -> Map.put(filters, :agent, value)
      end

    socket =
      socket
      |> assign(:filters, new_filters)
      |> filter_logs()

    {:noreply, socket}
  end

  defp filter_logs(socket) do
    filters = socket.assigns[:filters]

    new_filter =
      socket.assigns[:logs]
      |> Enum.filter(fn log ->
        cond do
          filters[:agent] != nil and filters[:agent] != log.from -> false
          true -> true
        end
      end)
      |> Enum.take(25)

    socket
    |> assign(:filtered_logs, new_filter)
  end

  defp apply_action(socket, :index, _params) do
    :ok = PubSub.subscribe(Teiserver.PubSub, "agent_updates")

    socket
    |> assign(:page_title, "Agents")
  end
end
