defmodule TeiserverWeb.Microblog.BlogLive.Preferences do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Microblog
  import TeiserverWeb.MicroblogComponents

  @impl true
  def mount(_params, _session, socket) do
    socket = if is_connected?(socket) do
      tags = Microblog.list_tags()
      |> Map.new(fn tag -> {tag.id, tag} end)

      socket
        |> assign(:tags, tags)
    else
      socket
        |> assign(:tags, %{})
    end

    {:ok,
      socket
      |> assign(:show_help_box, false)
      |> assign(:site_menu_active, "microblog")
      |> load_preferences()
      |> calculate_dont_care_tags
      |> assign(:view_colour, Microblog.colours())
    }
  end

  # @impl true
  # def handle_info(%{channel: "microblog_posts", event: :post_created, post: post}, socket) do
  #   db_post = Microblog.get_post!(post.id, preload: [:tags, :poster])

  #   {:noreply, stream_insert(socket, :posts, db_post, at: 0)}
  # end

  # def handle_info(%{channel: "microblog_posts", event: :post_updated, post: post}, socket) do
  #   db_post = Microblog.get_post!(post.id, preload: [:tags, :poster])

  #   {:noreply, stream_insert(socket, :posts, db_post, at: -1)}
  # end

  # def handle_info(%{channel: "microblog_posts", event: :post_deleted, post: post}, socket) do
  #   {:noreply, stream_delete(socket, :posts, post)}
  # end

  # def handle_info(%{channel: "microblog_posts"}, socket) do
  #   {:noreply, socket}
  # end

  @impl true
  def handle_event("toggle-help", _, %{assigns: assigns} = socket) do
    {:noreply, socket
      |> assign(:show_help_box, not assigns.show_help_box)}
  end

  def handle_event("toggle-disabled-tag", %{"tag-id" => tag_id_str}, %{assigns: assigns} = socket) do
    tag_id = String.to_integer(tag_id_str)

    new_user_preferences = if Enum.member?(assigns.user_preferences.disabled_tags, tag_id) do
      new_disabled_tags = List.delete(assigns.user_preferences.disabled_tags, tag_id)
      Map.put(assigns.user_preferences, :disabled_tags, new_disabled_tags)
    else
      new_disabled_tags = [tag_id | assigns.user_preferences.disabled_tags] |> Enum.uniq
      Map.put(assigns.user_preferences, :disabled_tags, new_disabled_tags)
    end

    {:noreply, socket
      |> assign(:user_preferences, new_user_preferences)
    }
  end

  def handle_event("toggle-enabled-tag", %{"tag-id" => tag_id_str}, %{assigns: assigns} = socket) do
    tag_id = String.to_integer(tag_id_str)

    new_user_preferences = if Enum.member?(assigns.user_preferences.enabled_tags, tag_id) do
      new_enabled_tags = List.delete(assigns.user_preferences.enabled_tags, tag_id)
      Map.put(assigns.user_preferences, :enabled_tags, new_enabled_tags)
    else
      new_enabled_tags = [tag_id | assigns.user_preferences.enabled_tags] |> Enum.uniq
      Map.put(assigns.user_preferences, :enabled_tags, new_enabled_tags)
    end

    {:noreply, socket
      |> assign(:user_preferences, new_user_preferences)
    }
  end

  defp load_preferences(%{assigns: %{current_user: nil}} = socket) do
    user_preferences = %{
      enabled_tags: [],
      disabled_tags: [],

      enabled_posters: [],
      disabled_posters: []
    }

    socket
      |> assign(:user_preferences, user_preferences)
  end

  defp load_preferences(%{assigns: %{current_user: current_user}} = socket) when is_connected?(socket) do
    user_preferences = case Microblog.get_user_preference(current_user.id) do
      nil ->
        %{
          enabled_tags: [],
          disabled_tags: [],

          enabled_posters: [],
          disabled_posters: []
        }

      user_preference ->
        %{
          enabled_tags: user_preference.enabled_tags || [],
          disabled_tags: user_preference.disabled_tags || [],

          enabled_posters: user_preference.enabled_posters || [],
          disabled_posters: user_preference.disabled_posters || []
        }
    end

    socket
      |> assign(:user_preferences, user_preferences)
  end

  defp load_preferences(socket) do
    user_preferences = %{
      enabled_tags: [],
      disabled_tags: [],

      enabled_posters: [],
      disabled_posters: []
    }

    socket
      |> assign(:user_preferences, user_preferences)
  end

  defp calculate_dont_care_tags(%{assigns: assigns} = socket) do
    combined_tags = assigns.user_preferences.enabled_tags ++ assigns.user_preferences.disabled_tags

    dont_care_tags = assigns.tags
      |> Map.keys()
      |> Enum.reject(fn tag_id -> Enum.member?(combined_tags, tag_id) end)

    socket
      |> assign(:dont_care_tags, dont_care_tags)
  end
end
