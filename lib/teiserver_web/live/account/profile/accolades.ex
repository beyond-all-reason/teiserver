defmodule TeiserverWeb.Account.ProfileLive.Accolades do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Account
  import Central.Helpers.ComponentHelper

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
          accolades =
            Account.list_accolades(
              search: [
                filter: {"recipient", userid}
              ],
              preload: [
                :giver,
                :recipient,
                :badge_type
              ],
              order_by: "Newest first"
            )

          error_message =
            cond do
              Enum.count(accolades) == 0 ->
                if user.id == socket.assigns.current_user.id,
                  do: "You have no accolades.",
                  else: "#{user.name} has no accolades."

              true ->
                nil
            end

          socket
          |> assign(:tab, nil)
          |> assign(:site_menu_active, "teiserver_account")
          |> assign(:view_colour, Teiserver.Account.UserLib.colours())
          |> assign(:user, user)
          |> assign(:error_message, error_message)
          |> assign(:accolades, accolades)
          |> TeiserverWeb.Account.ProfileLive.Overview.get_relationships_and_permissions()
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
