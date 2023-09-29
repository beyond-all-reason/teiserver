defmodule TeiserverWeb.Microblog.AdminLive.Index do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Microblog
  alias Teiserver.Microblog.Post
  import TeiserverWeb.Microblog.MicroblogComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
      socket
        |> assign(:post, %{})
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Post")
    |> assign(:post, Microblog.get_post!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Post")
    |> assign(:post, %{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Posts")
    |> assign(:post, %{})
  end

  @impl true
  def handle_info({TeiserverWeb.Microblog.PostFormComponent, {:saved, post}}, socket) do
    {:noreply, socket
      |> put_flash(:info, "Post created successfully")
      |> redirect(to: ~p"/microblog")
    }
  end

  def handle_info({TeiserverWeb.Microblog.PostFormComponent, {:updated_changeset, %{changes: post}}}, socket) do

    {:noreply, socket
      |> assign(:post, post)
    }
  end


  defp fake_data() do
    alias Teiserver.Microblog

    Microblog.create_tag(%{
      name: "Server",
      colour: "#AA00AA",
      icon: "fa-server"
    })

    Microblog.create_tag(%{
      name: "Mapping",
      colour: "#00AAAA",
      icon: "fa-map"
    })

    Microblog.create_tag(%{
      name: "Development",
      colour: "#00AA00",
      icon: "fa-code-commit"
    })

    Microblog.create_post(%{
      poster_id: 3,
      title: "Server post",
      contents: "Server post contents go here"
    })

    Microblog.create_post(%{
      poster_id: 3,
      title: "Mapping post",
      contents: "Mapping post contents are here"
    })

    Microblog.create_post(%{
      poster_id: 3,
      title: "Long long post",
      contents: "Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum"
    })

    Microblog.create_post(%{
      poster_id: 3,
      title: "XSS post",
      contents: "XSS <script>alert(1)</script>"
    })

    Microblog.create_post_tag(%{
      post_id: 1,
      tag_id: 1
    })

    Microblog.create_post_tag(%{
      post_id: 2,
      tag_id: 2
    })

    Microblog.create_post_tag(%{
      post_id: 1,
      tag_id: 3
    })

    Microblog.create_post_tag(%{
      post_id: 2,
      tag_id: 3
    })

    Microblog.create_post_tag(%{
      post_id: 3,
      tag_id: 3
    })
  end
end
