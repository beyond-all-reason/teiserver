defmodule TeiserverWeb.Microblog.Admin.UploadLive.Index do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Microblog

  @impl true
  def mount(_params, _session, socket) when is_connected?(socket) do
    user_uploads =
      Microblog.list_uploads(
        where: [uploader_id: socket.assigns.current_user.id],
        order_by: ["Newest first"]
      )

    socket
    |> assign(:view_colour, Teiserver.Microblog.colours())
    |> stream(:user_uploads, user_uploads)
    |> ok()
  end

  def mount(_params, _session, socket) do
    socket
    |> assign(:view_colour, Teiserver.Microblog.colours())
    |> stream(:user_uploads, [])
    |> ok()
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    upload = Microblog.get_upload!(id)

    if upload.uploader_id == socket.assigns.current_user.id do
      Microblog.delete_upload(upload)
    else
      raise "Not your upload"
    end

    socket
    |> stream_delete(:user_uploads, %{id: id})
    |> noreply()
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket
    |> apply_action(socket.assigns.live_action, params)
    |> noreply()
  end

  defp apply_action(socket, _action, _params) do
    socket
    |> assign(:page_title, "Microblog admin page")
    |> assign(:post, %{})
    |> assign(:site_menu_active, "blog")
  end
end
