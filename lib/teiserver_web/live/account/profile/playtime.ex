defmodule TeiserverWeb.Account.ProfileLive.Playtime do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Account

  @impl true
  def mount(%{"userid" => userid_str}, _session, socket) do
    userid = String.to_integer(userid_str)
    user = Account.get_user_by_id(userid)

    socket =
      cond do
        user == nil ->
          socket
          |> put_flash(:info, "Unable to find that user")
          |> redirect(to: ~p"/")

        true ->
          socket
          |> assign(:tab, nil)
          |> assign(:site_menu_active, "teiserver_account")
          |> assign(:view_colour, Teiserver.Account.UserLib.colours())
          |> assign(:user, user)
          |> TeiserverWeb.Account.ProfileLive.Overview.get_relationships_and_permissions()
          |> get_times()
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, _live_action, _params) do
    socket
    |> assign(:page_title, "Playtime")
  end

  @impl true
  def handle_event(_string, _event, socket) do
    {:noreply, socket}
  end

  defp get_times(socket) do
    stats = Account.get_user_stat_data(socket.assigns.user.id)

    total_hours = (Map.get(stats, "total_minutes", 0) / 60) |> round()
    player_hours = (Map.get(stats, "player_minutes", 0) / 60) |> round()
    spectator_hours = (Map.get(stats, "spectator_minutes", 0) / 60) |> round()

    socket
    |> assign(:total_hours, total_hours)
    |> assign(:player_hours, player_hours)
    |> assign(:spectator_hours, spectator_hours)
  end
end
