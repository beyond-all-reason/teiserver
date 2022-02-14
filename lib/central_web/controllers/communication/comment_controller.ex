defmodule CentralWeb.Communication.CommentController do
  use CentralWeb, :controller

  alias Central.Communication

  plug Bodyguard.Plug.Authorize,
    policy: Central.Communication.Comment,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  plug :add_breadcrumb, name: 'Blog', url: '/blog'
  plug :add_breadcrumb, name: 'Posts', url: '/blog_admin/comments'

  def index(conn, _params) do
    comments =
      Communication.list_comments(
        search: [
          # membership: conn,
          # basic_search: Map.get(params, "s", "") |> String.trim,
        ],
        joins: [:post, :poster],
        order_by: "Newest first"
      )

    conn
    |> assign(:comments, comments)
    |> render("index.html")
  end

  def show(conn, %{"id" => id}) do
    comment =
      Communication.get_comment!(id,
        joins: [
          :poster,
          :post
        ]
      )

    conn
    |> assign(:comment, comment)
    |> render("show.html")
  end

  def delete(conn, %{"id" => id}) do
    comment = Communication.get_comment!(id)

    {:ok, _comment} = Communication.delete_comment(comment)

    conn
    |> put_flash(:info, "Comment deleted successfully.")
    |> redirect(to: Routes.blog_post_path(conn, :show, comment.post_id) <> "#comments_tab")
  end
end
