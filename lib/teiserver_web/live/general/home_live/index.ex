defmodule TeiserverWeb.General.HomeLive.Index do
  alias Teiserver.Account.AuthLib

  use TeiserverWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{current_user: user} = socket.assigns

    mfa_warning? =
      AuthLib.mfa_required?() and AuthLib.contains_mfa_role?(user.roles) and
        not has_active_mfa?(user.id)

    socket = assign(socket, :mfa_warning?, mfa_warning?)

    socket =
      socket
      |> get_server_data()
      |> get_overwatch_data()
      |> get_moderation_data()

    {:ok, socket}
  end

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
