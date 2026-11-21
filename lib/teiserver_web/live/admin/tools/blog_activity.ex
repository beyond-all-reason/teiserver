defmodule TeiserverWeb.AdminLive.Tools.BlogActivity do
  @moduledoc false
  alias Teiserver.Microblog
  alias TeiserverWeb.AdminLive.ToolsComponents

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, %Socket{} = socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(_params, _url, %Socket{} = socket) when is_connected?(socket) do
    post_data =
      Microblog.list_posts(
        order_by: "Newest first",
        preload: [:poster]
      )

    socket
    |> assign(
      page_title: "Blog usage",
      post_count: Enum.count(post_data),
      connected?: true
    )
    |> stream(:post_data, post_data)
    |> noreply()
  end

  def handle_params(_params, _url, %Socket{} = socket) do
    socket
    |> assign(connected?: false, post_count: 0)
    |> noreply()
  end
end
