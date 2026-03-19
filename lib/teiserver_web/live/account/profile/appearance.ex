defmodule TeiserverWeb.Account.ProfileLive.Appearance do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Account
  alias Teiserver.Account.RoleLib
  alias Teiserver.Account.UserLib
  alias TeiserverWeb.Account.ProfileLive.Overview

  @impl Phoenix.LiveView
  def mount(%{"userid" => userid_str}, _session, socket) do
    userid = String.to_integer(userid_str)
    user = Account.get_user_by_id(userid)

    socket =
      if is_nil(user) do
        socket
        |> put_flash(:info, "Unable to find that user")
        |> redirect(to: ~p"/")
      else
        socket
        |> assign(:tab, nil)
        |> assign(:site_menu_active, "teiserver_account")
        |> assign(:view_colour, UserLib.colours())
        |> assign(:user, user)
        |> Overview.get_relationships_and_permissions()
        |> list_icons()
      end

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, _live_action, _params) do
    socket
    |> assign(:page_title, "Appearance")
  end

  @impl Phoenix.LiveView
  def handle_event("select-style", %{"role" => role_name}, %{assigns: assigns} = socket) do
    available =
      assigns.options
      |> Enum.map(fn r -> r.name end)

    role_def =
      if Enum.member?(available, role_name) do
        if RoleLib.role_data(role_name) do
          RoleLib.role_data(role_name)
        else
          RoleLib.role_data("Default")
        end
      else
        RoleLib.role_data("Default")
      end

    user = Account.get_user!(assigns.current_user.id)

    {:ok, user} =
      Account.update_user(user, %{
        colour: role_def.colour,
        icon: role_def.icon
      })

    {:noreply,
     socket
     |> assign(:current_user, user)}
  end

  def handle_event(_string, _event, socket) do
    {:noreply, socket}
  end

  defp list_icons(%{assigns: assigns} = socket) do
    my_perms = assigns.current_user.permissions
    role_data = RoleLib.role_data()

    filtered_roles =
      RoleLib.all_role_names()
      |> Enum.filter(fn role_name ->
        Enum.member?(my_perms, role_name) and RoleLib.role_data(role_name).badge
      end)

    options =
      (RoleLib.global_roles() ++ filtered_roles)
      |> Enum.map(fn r ->
        role_data[r]
      end)

    socket
    |> assign(:options, options)
  end
end
