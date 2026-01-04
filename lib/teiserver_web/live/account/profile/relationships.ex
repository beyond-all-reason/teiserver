defmodule TeiserverWeb.Account.ProfileLive.Relationships do
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
          |> get_mutuals()
          |> check_page_permissions()
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, _live_action, _params) do
    socket
    |> assign(:page_title, "Relationships")
  end

  @impl true
  def handle_event(_string, _event, socket) do
    {:noreply, socket}
  end

  def get_mutuals(socket) do
    your_friends = Account.list_friend_ids_of_user(socket.assigns.current_user.id)
    their_friends = Account.list_friend_ids_of_user(socket.assigns.user.id)

    mutual_friend_ids =
      your_friends
      |> Enum.filter(fn friend_id ->
        Enum.member?(their_friends, friend_id)
      end)

    mutual_friends =
      Account.list_users_from_cache(mutual_friend_ids)
      |> Enum.sort_by(fn user -> user.name end, &<=/2)

    socket
    |> assign(:mutual_friends, mutual_friends)
  end

  defp check_page_permissions(%{assigns: assigns} = socket) do
    allowed =
      not Enum.member?(assigns.profile_permissions, :self) and
        Enum.member?(assigns.profile_permissions, :friend)

    if allowed do
      socket
    else
      socket
      |> redirect(to: ~p"/profile/#{assigns.user.id}")
    end
  end
end
