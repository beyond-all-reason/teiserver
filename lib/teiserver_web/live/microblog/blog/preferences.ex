defmodule TeiserverWeb.Microblog.BlogLive.Preferences do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Microblog
  import TeiserverWeb.MicroblogComponents
  alias Teiserver.Microblog.UserPreferenceLib

  @default_preferences %{
    tag_mode: "Block",
    enabled_tags: [],
    disabled_tags: [],
    enabled_posters: [],
    disabled_posters: []
  }

  @impl true
  def mount(_params, _session, socket) do
    socket =
      if is_connected?(socket) do
        tags = Microblog.list_tags(order_by: "Name (A-Z)")

        tag_order = tags |> Enum.map(fn t -> t.id end)

        tag_map =
          tags
          |> Map.new(fn tag -> {tag.id, tag} end)

        socket
        |> assign(:tag_order, tag_order)
        |> assign(:tag_map, tag_map)
      else
        socket
        |> assign(:tag_order, [])
        |> assign(:tag_map, %{})
      end

    {:ok,
     socket
     |> assign(:show_help_box, false)
     |> assign(:site_menu_active, "microblog")
     |> assign(:view_colour, Microblog.colours())
     |> assign(:tag_mode_list, UserPreferenceLib.tag_mode_list())
     |> assign(:default_preferences, @default_preferences)
     |> load_preferences()}
  end

  @impl true
  def handle_event("toggle-help", _, %{assigns: assigns} = socket) do
    {:noreply,
     socket
     |> assign(:show_help_box, not assigns.show_help_box)}
  end

  def handle_event("change-tag-mode", %{"tag-mode" => new_mode}, socket) do
    socket = maybe_make_user_preferences(socket)

    socket =
      if socket.assigns.user_preferences.tag_mode == new_mode do
        socket
      else
        {enabled, disabled} =
          case new_mode do
            "Block" ->
              {[], socket.assigns.user_preferences.disabled_tags}

            "Filter" ->
              {socket.assigns.user_preferences.enabled_tags, []}

            "Filter and block" ->
              {socket.assigns.user_preferences.enabled_tags,
               socket.assigns.user_preferences.disabled_tags}
          end

        {:ok, new_user_preferences} =
          Microblog.update_user_preference(
            socket.assigns.user_preferences,
            %{
              tag_mode: new_mode,
              enabled_tags: enabled,
              disabled_tags: disabled
            }
          )

        socket
        |> assign(:user_preferences, new_user_preferences)
        |> calculate_remaining_tags()
      end

    {:noreply, socket}
  end

  def handle_event("enable-tag", %{"tag-id" => tag_id_str}, socket) do
    socket = maybe_make_user_preferences(socket)
    tag_id = String.to_integer(tag_id_str)

    user_preferences = socket.assigns.user_preferences

    new_enabled = [tag_id | user_preferences.enabled_tags] |> Enum.uniq()
    new_disabled = List.delete(user_preferences.disabled_tags, tag_id)

    {:ok, new_user_preferences} =
      Microblog.update_user_preference(
        user_preferences,
        %{
          enabled_tags: new_enabled,
          disabled_tags: new_disabled
        }
      )

    {:noreply,
     socket
     |> assign(:user_preferences, new_user_preferences)
     |> calculate_remaining_tags()}
  end

  def handle_event("disable-tag", %{"tag-id" => tag_id_str}, socket) do
    socket = maybe_make_user_preferences(socket)
    tag_id = String.to_integer(tag_id_str)

    user_preferences = socket.assigns.user_preferences

    new_enabled = List.delete(user_preferences.enabled_tags, tag_id)
    new_disabled = [tag_id | user_preferences.disabled_tags] |> Enum.uniq()

    {:ok, new_user_preferences} =
      Microblog.update_user_preference(
        user_preferences,
        %{
          enabled_tags: new_enabled,
          disabled_tags: new_disabled
        }
      )

    {:noreply,
     socket
     |> assign(:user_preferences, new_user_preferences)
     |> calculate_remaining_tags()}
  end

  def handle_event("reset-tag", %{"tag-id" => tag_id_str}, socket) do
    socket = maybe_make_user_preferences(socket)
    tag_id = String.to_integer(tag_id_str)

    user_preferences = socket.assigns.user_preferences

    new_enabled = List.delete(user_preferences.enabled_tags, tag_id)
    new_disabled = List.delete(user_preferences.disabled_tags, tag_id)

    {:ok, new_user_preferences} =
      Microblog.update_user_preference(
        user_preferences,
        %{
          enabled_tags: new_enabled,
          disabled_tags: new_disabled
        }
      )

    {:noreply,
     socket
     |> assign(:user_preferences, new_user_preferences)
     |> calculate_remaining_tags()}
  end

  defp load_preferences(%{assigns: %{current_user: nil}} = socket) do
    socket
    |> assign(:user_preferences, nil)
    |> calculate_remaining_tags()
  end

  defp load_preferences(%{assigns: %{current_user: current_user}} = socket)
       when is_connected?(socket) do
    user_preferences = Microblog.get_user_preference(current_user.id)

    socket
    |> assign(:user_preferences, user_preferences)
    |> calculate_remaining_tags()
  end

  defp load_preferences(socket) do
    socket
    |> assign(:user_preferences, nil)
    |> calculate_remaining_tags()
  end

  defp calculate_remaining_tags(%{assigns: assigns} = socket) do
    taken_tag_ids =
      case assigns.user_preferences do
        nil ->
          []

        %{tag_mode: "Filter"} ->
          assigns.user_preferences.enabled_tags

        %{tag_mode: "Filter and block"} ->
          assigns.user_preferences.enabled_tags ++ assigns.user_preferences.disabled_tags

        %{tag_mode: _block} ->
          assigns.user_preferences.disabled_tags
      end

    remaining_tags =
      assigns.tag_order
      |> Enum.reject(fn tag_id -> Enum.member?(taken_tag_ids, tag_id) end)

    socket
    |> assign(:remaining_tags, remaining_tags)
  end

  defp maybe_make_user_preferences(%{assigns: %{user_preferences: nil}} = socket) do
    params = Map.put(@default_preferences, :user_id, socket.assigns.current_user.id)
    {:ok, new_user_preferences} = Microblog.create_user_preference(params)

    socket
    |> assign(:user_preferences, new_user_preferences)
  end

  defp maybe_make_user_preferences(socket), do: socket
end
