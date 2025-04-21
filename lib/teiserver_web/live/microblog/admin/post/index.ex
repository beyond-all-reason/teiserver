defmodule TeiserverWeb.Microblog.Admin.PostLive.Index do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Microblog

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case allow?(socket.assigns[:current_user], "Blog helper") do
      true ->
        {:noreply, apply_action(socket, socket.assigns.live_action, params)}

      false ->
        {:noreply,
         socket
         |> redirect(to: ~p"/microblog")}
    end
  end

  defp apply_action(socket, _action, _params) do
    socket
    |> assign(:page_title, "Microblog admin page")
    |> assign(:post, %{})
    |> assign(:site_menu_active, "microblog")
    |> assign(:view_colour, Microblog.colours())
  end

  @impl true
  def handle_info({TeiserverWeb.Microblog.PostFormComponent, {:saved, _post}}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Post created successfully")
     |> redirect(to: ~p"/microblog")}
  end

  def handle_info(
        {TeiserverWeb.Microblog.PostFormComponent, {:updated_changeset, %{changes: post}}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:post, post)}
  end
end
