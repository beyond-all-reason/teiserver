defmodule TeiserverWeb.Account.ProfileLive.Matches do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.{Account, Battle, Config, Game}
  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

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
          |> Teiserver.Plugs.CachePlug.live_call()
          |> assign(:tab, nil)
          |> assign(:site_menu_active, "teiserver_account")
          |> assign(:view_colour, Teiserver.Account.UserLib.colours())
          |> assign(:user, user)
          |> TeiserverWeb.Account.ProfileLive.Overview.get_relationships_and_permissions()
          |> assign_pagination_defaults()
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    parsed = TeiserverWeb.Parsers.PaginationParams.parse_params(params)

    socket =
      socket
      |> assign(:page, parsed.page - 1)
      |> assign(:limit, parsed.limit)
      |> check_privacy_and_load_matches()

    {:noreply, socket}
  end

  @impl true
  def handle_event(_string, _event, socket) do
    {:noreply, socket}
  end

  defp assign_pagination_defaults(socket) do
    socket
    |> assign(:page, 0)
    |> assign(:limit, 50)
    |> assign(:total_count, 0)
    |> assign(:total_pages, 1)
    |> assign(:current_count, 0)
    |> assign(:matches, [])
    |> assign(:can_view_matches, false)
  end

  defp check_privacy_and_load_matches(socket) do
    can_view_matches =
      can_view_match_history?(socket.assigns.user, socket.assigns.profile_permissions)

    can_view_ratings = can_view_ratings?(socket.assigns.user, socket.assigns.profile_permissions)

    socket =
      socket
      |> assign(:can_view_matches, can_view_matches)
      |> assign(:can_view_ratings, can_view_ratings)

    if can_view_matches do
      load_user_matches(socket)
    else
      socket
    end
  end

  def can_view_match_history?(profile_user, profile_permissions) do
    match_visibility =
      Config.get_user_config_cache(profile_user, "privacy.Match history visibility")

    case match_visibility do
      "Only myself" -> :self in profile_permissions
      "Friends" -> :self in profile_permissions or :friend in profile_permissions
      "Any player" -> not Enum.any?(profile_permissions, &(&1 in [:block, :avoid, :ignore]))
      "Completely public" -> true
      _ -> false
    end
  end

  def can_view_ratings?(profile_user, profile_permissions) do
    ratings_visibility = Config.get_user_config_cache(profile_user, "privacy.Ratings visibility")

    case ratings_visibility do
      "Only myself" -> :self in profile_permissions
      "Friends" -> :self in profile_permissions or :friend in profile_permissions
      "Any player" -> not Enum.any?(profile_permissions, &(&1 in [:block, :avoid, :ignore]))
      "Completely public" -> true
      _ -> false
    end
  end

  defp load_rating_data_for_matches(matches, user_id) do
    match_ids = Enum.map(matches, & &1.id)

    rating_data =
      if match_ids != [] do
        Game.list_rating_logs(search: [match_id_in: match_ids, user_id: user_id])
        |> Map.new(&{&1.match_id, &1})
      else
        %{}
      end

    Enum.map(matches, fn match ->
      rating_log = Map.get(rating_data, match.id)

      match
      |> Map.put(:rating_log, rating_log)
      |> Map.put(:rating_change, rating_log && get_in(rating_log.value, ["rating_value_change"]))
      |> Map.put(:rating, rating_log && get_in(rating_log.value, ["rating_value"]))
    end)
  end

  defp load_user_matches(%{assigns: %{user: user, page: page, limit: limit}} = socket) do
    if connected?(socket) do
      search_criteria = [has_started: true, user_id: user.id]

      total_count = Battle.count_matches(search: search_criteria)

      matches =
        Battle.list_matches(
          search: search_criteria,
          preload: [:queue],
          order_by: "Newest first",
          limit: limit,
          offset: page * limit
        )

      matches_with_ratings = load_rating_data_for_matches(matches, user.id)

      socket
      |> assign(:matches, matches_with_ratings)
      |> assign(:total_count, total_count)
      |> assign(:total_pages, max(1, div(total_count - 1, limit) + 1))
      |> assign(:current_count, length(matches))
    else
      socket
      |> assign(:matches, [])
      |> assign(:total_count, 0)
      |> assign(:total_pages, 1)
      |> assign(:current_count, 0)
    end
  end

  defp rating_change_display_class_and_icon(rating_change) do
    cond do
      rating_change > 0 -> {"text-success", "arrow-up"}
      rating_change < 0 -> {"text-danger", "arrow-down"}
      true -> {"text-warning", "pause"}
    end
  end
end
