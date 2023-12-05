defmodule TeiserverWeb.Microblog.Admin.TagLive.Index do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Microblog
  import TeiserverWeb.MicroblogComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case allow?(socket.assigns[:current_user], "Server") do
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
    |> assign(:tags, Microblog.list_tags(order_by: ["Name (A-Z)"]))
    |> assign(:tag, nil)
    |> assign(:site_menu_active, "microblog")
    |> assign(:view_colour, Teiserver.Microblog.colours())
  end

  @impl true
  def handle_info({TeiserverWeb.Microblog.TagFormComponent, {:saved, _tag}}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Tag created successfully")
     |> redirect(to: ~p"/microblog/admin/tags")}
  end

  def handle_info(
        {TeiserverWeb.Microblog.TagFormComponent, {:updated_changeset, %{changes: tag}}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:tag, tag)}
  end
end
