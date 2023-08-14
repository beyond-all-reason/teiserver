defmodule TeiserverWeb.Account.ProfileLive.Accolades do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Account

  @impl true
  def mount(%{"userid" => userid_str}, _session, socket) do
    userid = String.to_integer(userid_str)
    user = Account.get_user_by_id(userid)

    socket = cond do
      user == nil ->
        socket
          |> put_flash(:info, "Unable to find that user")
          |> redirect(to: ~p"/")

      true ->
        socket
          |> assign(:tab, nil)
          |> assign(:site_menu_active, "account")
          |> assign(:view_colour, Teiserver.Account.UserLib.colours())
          |> assign(:user, user)
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, _live_action, _params) do
    socket
      |> assign(:page_title, "Accolades")
  end

  @impl true
  def handle_event(_string, _event, socket) do
    {:noreply, socket}
  end
end
