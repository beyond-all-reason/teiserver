defmodule TeiserverWeb.Microblog.RssController do
  use TeiserverWeb, :controller
  alias Teiserver.Microblog
  alias Teiserver.Helper.TimexHelper

  plug :put_layout, false
  plug :put_root_layout, false

  def index(conn, _params) do
    posts =
      Microblog.list_posts(
        where: [
          # enabled_tags: filters.enabled_tags,
          # disabled_tags: filters.disabled_tags,

          poster_id_in: [],
          poster_id_not_in: []
        ],
        order_by: ["Newest first"],
        limit: 50,
        preload: [:tags, :poster, :discord_channel]
      )

    last_build_date =
      posts
      |> Enum.map(fn p -> p.updated_at end)
      |> Enum.sort_by(fn v -> v end, &TimexHelper.greater_than/2)
      |> hd()

    conn
    |> put_resp_content_type("text/xml")
    |> assign(:posts, posts)
    |> assign(:last_build_date, last_build_date)
    |> render("index.xml")
  end

  def html_mode(conn, _params) do
    posts =
      Microblog.list_posts(
        where: [
          # enabled_tags: filters.enabled_tags,
          # disabled_tags: filters.disabled_tags,

          poster_id_in: [],
          poster_id_not_in: []
        ],
        order_by: ["Newest first"],
        limit: 50,
        preload: [:tags, :poster, :discord_channel]
      )

    last_build_date =
      posts
      |> Enum.map(fn p -> p.updated_at end)
      |> Enum.sort_by(fn v -> v end, &TimexHelper.greater_than/2)
      |> hd()

    conn
    |> put_resp_content_type("text/xml")
    |> assign(:posts, posts)
    |> assign(:last_build_date, last_build_date)
    |> render("index_html.xml")
  end
end
