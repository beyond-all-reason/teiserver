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
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, _action, _params) do
    socket
    |> assign(:page_title, "Microblog admin page")
        |> assign(:post, %{})
        |> assign(:tag, %{})
  end

  @impl true
  def handle_info({TeiserverWeb.Microblog.PostFormComponent, {:saved, post}}, socket) do
    {:noreply, socket
      |> put_flash(:info, "Post created successfully")
      |> redirect(to: ~p"/microblog/admin")
    }
  end

  def handle_info({TeiserverWeb.Microblog.PostFormComponent, {:updated_changeset, %{changes: post}}}, socket) do

    {:noreply, socket
      |> assign(:post, post)
    }
  end


  def handle_info({TeiserverWeb.Microblog.TagFormComponent, {:saved, tag}}, socket) do
    {:noreply, socket
      |> put_flash(:info, "Tag created successfully")
      |> redirect(to: ~p"/microblog/admin")
    }
  end

  def handle_info({TeiserverWeb.Microblog.TagFormComponent, {:updated_changeset, %{changes: tag}}}, socket) do

    {:noreply, socket
      |> assign(:tag, tag)
    }
  end


  def fake_data() do
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
    :timer.sleep(1000)

    Microblog.create_post(%{
      poster_id: 3,
      title: "Mapping post",
      contents: "Mapping post contents are here"
    })
    :timer.sleep(1000)

    Microblog.create_post(%{
      poster_id: 3,
      title: "Long long post",
      contents: "Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum Lorem ipsum"
    })
    :timer.sleep(1000)

    Microblog.create_post(%{
      poster_id: 3,
      title: "XSS post",
      contents: "XSS <script>alert(1)</script>"
    })
    :timer.sleep(1000)

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
