defmodule TeiserverWeb.Microblog.AdminLive.Index do
@moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Microblog
  import TeiserverWeb.Microblog.MicroblogComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
      socket
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    case allow?(socket.assigns[:current_user], "Moderator") do
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
        |> assign(:tag, %{})
  end

  @impl true
  def handle_info({TeiserverWeb.Microblog.PostFormComponent, {:saved, _post}}, socket) do
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


  def handle_info({TeiserverWeb.Microblog.TagFormComponent, {:saved, _tag}}, socket) do
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

    {:ok, server_post} = Microblog.create_post(%{
      poster_id: 3,
      title: "Server post",
      contents: "Server post contents go here, this is a run-on sentence for testing purposes. This is a run-on sentence for testing purposes. This is a run-on sentence for testing purposes. This is a run-on sentence for testing purposes. This is a run-on sentence for testing purposes. This is a run-on sentence for testing purposes. This is a run-on sentence for testing purposes."
    })
    :timer.sleep(1000)

    Microblog.create_post_tag(%{
      post_id: server_post.id,
      tag_id: 1
    })

    {:ok, mapping_post} = Microblog.create_post(%{
      poster_id: 3,
      title: "Mapping post",
      contents: "Mapping post contents are here"
    })
    :timer.sleep(1000)

    Microblog.create_post_tag(%{
      post_id: mapping_post.id,
      tag_id: 2
    })

    {:ok, dev_post} = Microblog.create_post(%{
      poster_id: 3,
      title: "Development post",
      contents: "Development post contents are here"
    })
    :timer.sleep(1000)

    Microblog.create_post_tag(%{
      post_id: dev_post.id,
      tag_id: 3
    })

    {:ok, dev_mapping_post} = Microblog.create_post(%{
      poster_id: 3,
      title: "Development and Mapping post",
      contents: "Development and Mapping post contents are here"
    })
    :timer.sleep(1000)

    Microblog.create_post_tag(%{
      post_id: dev_mapping_post.id,
      tag_id: 2
    })

    Microblog.create_post_tag(%{
      post_id: dev_mapping_post.id,
      tag_id: 3
    })

    {:ok, dev_server_post} = Microblog.create_post(%{
      poster_id: 3,
      title: "Development and Sever post",
      contents: "Development and Sever post contents are here"
    })
    :timer.sleep(1000)

    Microblog.create_post_tag(%{
      post_id: dev_server_post.id,
      tag_id: 1
    })

    Microblog.create_post_tag(%{
      post_id: dev_server_post.id,
      tag_id: 3
    })

  end
end
