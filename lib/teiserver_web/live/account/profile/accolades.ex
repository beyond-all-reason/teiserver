defmodule TeiserverWeb.Account.ProfileLive.Accolades do
  @moduledoc false
  alias Teiserver.Account.AccoladeLib
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
              search: [recipient_id: userid, has_badge: true],
              preload: [
                :giver,
                :recipient,
                :badge_type
              ],
              order_by: "Newest first"
            )

          socket
          |> assign(:tab, nil)
          |> assign(:site_menu_active, "teiserver_account")
          |> assign(:view_colour, Teiserver.Account.UserLib.colours())
          |> assign(:user, user)
          |> assign(:accolades, accolades)
          |> assign_summary()
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

  defp assign_summary(socket) do
    current_user_id = socket.assigns.current_user && socket.assigns.current_user.id
    viewed_user_id = socket.assigns.user.id
    viewed_user_name = socket.assigns.user.name

    {unique_giver_count, total_accolades} = AccoladeLib.get_unique_giver_count(viewed_user_id)

    # The summary will contain a message for the number of unique users that have gifted this user an accolade.
    # Multiple accolades from the same person won't increase their unique count. They are still in the list though.
    message =
      cond do
        total_accolades == 0 ->
          "You have no accolades."

        true ->
          "You have received #{total_accolades} accolades from #{unique_giver_count} unique users."
      end
      |> fix_pronouns(current_user_id, viewed_user_id, viewed_user_name)

    socket |> assign(:summary, message)
  end

  defp fix_pronouns(message, current_user_id, viewed_user_id, viewed_user_name) do
    if current_user_id != viewed_user_id do
      # When viewing someone else's accolades, replace "you" with person's name
      String.replace(message, "You have", "#{viewed_user_name} has")
    else
      message
    end
  end
end
