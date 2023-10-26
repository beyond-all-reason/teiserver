defmodule TeiserverWeb.Microblog.RssController do
  use CentralWeb, :controller
  alias Teiserver.Microblog

  plug :put_layout, false
  plug :put_root_layout, false

  def index(conn, _params) do
    posts = Microblog.list_posts(
      where: [
        # enabled_tags: filters.enabled_tags,
        # disabled_tags: filters.disabled_tags,

        poster_id_in: [],
        poster_id_not_in: []
      ],
      order_by: ["Newest first"],
      limit: 50,
      preload: [:tags, :poster]
    )

    conn
    |> put_resp_content_type("text/xml")
    |> assign(:posts, posts)
    |> render("index.xml")
  end
end
