defmodule TeiserverWeb.Account.ProfileLive.Contributor do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.{Account, Config}

  @impl true
  def mount(%{"userid" => userid_str}, _session, socket) do
    userid = String.to_integer(userid_str)
    user = Account.get_user_by_id(userid)
    hide_contributor_rank = Account.hide_contributor_rank?(userid)

    socket =
      cond do
        user == nil ->
          socket
          |> put_flash(:info, "Unable to find that user")
          |> redirect(to: ~p"/")

        not allow?(user, "BAR+") ->
          socket
          |> put_flash(:info, "You do not have permission to access this section")
          |> redirect(to: ~p"/profile")

        true ->
          socket
          |> assign(:tab, nil)
          |> assign(:site_menu_active, "teiserver_account")
          |> assign(:view_colour, Teiserver.Account.UserLib.colours())
          |> assign(:user, user)
          |> assign(:error_message, nil)
          |> assign(:hide_contributor_rank, hide_contributor_rank)
          |> TeiserverWeb.Account.ProfileLive.Overview.get_relationships_and_permissions()
          |> user_assigns()
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, _live_action, _params) do
    socket
    |> assign(:page_title, "Contributor")
  end

  @impl true
  def handle_event("set-temp_country_code", %{"value" => ""}, socket) do
    {:noreply,
     socket
     |> assign(:temp_country_code, nil)}
  end

  def handle_event("set-temp_country_code", %{"value" => country_code}, socket) do
    {:noreply,
     socket
     |> assign(:temp_country_code, country_code)}
  end

  def handle_event("revert-country_code", _, %{assigns: assigns} = socket) do
    {:noreply,
     socket
     |> assign(:temp_country_code, assigns.stats["bar_plus.flag"])
     |> assign(:error_message, nil)}
  end

  def handle_event("clear-country_code", _, %{assigns: assigns} = socket) do
    Account.update_user_stat(assigns.user.id, %{
      "bar_plus.flag" => nil
    })

    {:noreply,
     socket
     |> assign(:temp_country_code, "")
     |> assign(:error_message, nil)}
  end

  def handle_event("save-country_code", _, %{assigns: assigns} = socket) do
    if String.match?(assigns.temp_country_code, ~r/^[a-zA-Z0-9-]{2,16}$/) do
      Account.update_user_stat(assigns.user.id, %{
        "bar_plus.flag" => assigns.temp_country_code
      })

      Account.recache_user(assigns.user.id)

      {:noreply,
       socket
       |> assign(:country_code, assigns.temp_country_code)
       |> assign(:error_message, nil)}
    else
      {:noreply,
       socket
       |> assign(:error_message, "Country code must not contain space")}
    end
  end

  @doc """
  Handles checkbox to disable contributor rank icon
  """
  @impl true
  def handle_event("toggle-hide-contributor-rank", event, %{assigns: assigns} = socket) do
    [key] = event["_target"]
    value = event[key]

    # value will be a string or nil; we will convert to boolean
    boolean_value =
      if value do
        true
      else
        false
      end

    Account.set_hide_contributor_rank(assigns.user.id, boolean_value)
    Account.recache_user(assigns.user.id)

    {:noreply,
     socket
     |> assign(:hide_contributor_rank, boolean_value)}
  end

  def handle_event(_string, _event, socket) do
    {:noreply, socket}
  end

  defp user_assigns(%{assigns: %{user: user}} = socket) do
    country_code = user.country
    stats = Account.get_user_stat_data(user.id)

    socket
    |> assign(:country_code, country_code)
    |> assign(:temp_country_code, stats["bar_plus.flag"])
    |> assign(:stats, stats)
    |> assign(:show_flag_config, Config.get_user_config_cache(user.id, "teiserver.Show flag"))
  end
end
