defmodule TeiserverWeb.Battle.GiveAccoladeLive.Index do
  alias Teiserver.Account.AccoladeLib
  use TeiserverWeb, :live_view
  alias Teiserver.{Account}
  alias Teiserver.Config
  import Central.Helpers.ComponentHelper

  @impl true
  def mount(_params, _session, socket) do
    badge_types =
      Account.list_badge_types(order_by: "Name (A-Z)")

    gift_limit = Config.get_site_config_cache("teiserver.Accolade gift limit")
    gift_window = Config.get_site_config_cache("teiserver.Accolade gift window")

    socket =
      socket
      |> assign(:view_colour, Teiserver.Account.UserLib.colours())
      |> assign(:user, nil)
      |> assign(:stage, :loading)
      |> assign(:extra_text, "")
      |> assign(:badge_types, badge_types)
      |> assign(:gift_limit, gift_limit)
      |> assign(:gift_window, gift_window)
      |> add_breadcrumb(name: "Give Accolade", url: ~p"/")

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"user_id" => user_id, "id" => match_id}, _url, socket) do
    user = Account.get_user_by_id(user_id)
    {match_id, _} = Integer.parse(match_id)

    socket =
      socket
      |> assign(:id_str, user_id)
      |> assign(:user, user)
      |> assign(:stage, :form)
      |> assign(:match_id, match_id)
      |> allowed_to_use_form

    {:noreply, socket}
  end

  defp allowed_to_use_form(%{assigns: %{current_user: current_user, user: target_user}} = socket) do
    {allowed, failure_reason} =
      cond do
        current_user == nil ->
          {false, "You must be logged in to give an accolade to someone"}

        current_user.id == target_user.id ->
          {false, "You cannot give accolades to yourself"}

        true ->
          {true, nil}
      end

    if allowed do
      socket
      |> assign_gift_history()
    else
      socket
      |> assign(:failure_reason, failure_reason)
      |> assign(:stage, :not_allowed)
    end
  end

  defp assign_gift_history(socket) do
    gift_window = socket.assigns.gift_window
    user_id = socket.assigns.current_user.id
    gift_count = AccoladeLib.get_number_of_gifted_accolades(user_id, gift_window)
    gift_limit = socket.assigns.gift_limit

    if gift_count >= gift_limit do
      socket
      |> assign(
        :failure_reason,
        "You can only gift #{gift_limit} accolades every #{gift_window} days."
      )
      |> assign(:stage, :not_allowed)
    else
      socket
      |> assign(:gift_count, gift_count)
    end
  end

  @impl true
  def handle_event("give-accolade", args, socket) do
    %{"id" => badge_id} = args

    recipient_id = socket.assigns.user.id

    current_user = socket.assigns.current_user

    match_id = socket.assigns.match_id

    Account.create_accolade(%{
      recipient_id: recipient_id,
      giver_id: current_user.id,
      match_id: match_id,
      inserted_at: Timex.now(),
      badge_type_id: badge_id
    })

    socket = socket |> assign(:stage, :complete)

    {:noreply, socket}
  end
end
