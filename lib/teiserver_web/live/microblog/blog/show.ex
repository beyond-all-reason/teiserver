defmodule TeiserverWeb.Microblog.BlogLive.Show do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.{Microblog, Logging, Communication}
  import TeiserverWeb.MicroblogComponents
  alias Phoenix.PubSub

  @impl true
  def mount(%{"post_id" => post_id_str}, _session, socket) do
    socket =
      if is_connected?(socket) do
        :ok = PubSub.subscribe(Teiserver.PubSub, "microblog_posts")
        post = Microblog.get_post!(post_id_str, preload: [:poster, :tags])
        Microblog.increment_post_view_count(post.id)

        socket
        |> assign(:post, post)
      else
        socket
        |> assign(:post, nil)
      end

    {:ok,
     socket
     |> assign(:site_menu_active, "microblog")}
  end

  @impl true
  def handle_info(%{channel: "microblog_posts", event: :post_created}, socket) do
    {:noreply, socket}
  end

  def handle_info(
        %{channel: "microblog_posts", event: :post_updated, post: new_post},
        %{assigns: %{post: post}} = socket
      ) do
    socket =
      if post.id == new_post.id do
        db_post = Microblog.get_post!(post.id, preload: [:tags, :poster])
        socket |> assign(:post, db_post)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(
        %{channel: "microblog_posts", event: :post_deleted, post_id: post_id},
        %{assigns: %{post: post}} = socket
      ) do
    if post_id == post.id do
      {:noreply,
       socket
       |> redirect(to: ~p"/microblog")}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{channel: "microblog_posts"}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete-post", _, %{assigns: %{post: post} = assigns} = socket) do
    if assigns.current_user.id == post.poster_id || allow?(assigns.current_user, "Moderator") do
      Microblog.delete_post(post)

      if post.discord_post_id do
        Communication.delete_discord_message(post.discord_channel_id, post.discord_post_id)
      end

      Logging.add_audit_log(socket, "Microblog.delete_post", %{
        title: post.title,
        post_id: post.id
      })

      {:noreply,
       socket
       |> redirect(to: ~p"/microblog")}
    else
      {:noreply, socket}
    end
  end
end
