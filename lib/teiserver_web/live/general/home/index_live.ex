defmodule TeiserverWeb.General.HomeLive.Index do
  use TeiserverWeb, :live_view
  # alias Teiserver.{Account, Battle}

  @impl true
  def mount(_params, _session, socket) do
    socket = socket
      |> get_server_data()
      |> get_overwatch_data()
      |> get_moderation_data()

    {:ok, socket}
  end

  # @impl true
  # def handle_event(_cmd, _event, %{assigns: _assigns} = socket) do
  #   {:noreply, socket}
  # end

  defp get_server_data(%{assigns: %{current_user: current_user}} = socket) do
    if allow?(current_user, "Server") do
      socket
    else
      socket
    end
  end

  defp get_overwatch_data(%{assigns: %{current_user: current_user}} = socket) do
    if allow?(current_user, "Overwatch") do
      outstanding_reports = 0

      socket
      |> assign(:outstanding_reports, outstanding_reports)
    else
      socket
    end
  end

  defp get_moderation_data(%{assigns: %{current_user: current_user}} = socket) do
    if allow?(current_user, "Moderator") do
      outstanding_appeals = 0

      socket
      |> assign(:outstanding_appeals, outstanding_appeals)
    else
      socket
    end
  end
end
