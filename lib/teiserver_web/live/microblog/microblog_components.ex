defmodule TeiserverWeb.Microblog.MicroblogComponents do
  @moduledoc false
  use CentralWeb, :component
  alias Teiserver.Helper.TimexHelper
  # import TeiserverWeb.NavComponents, only: [sub_menu_button: 1]

  @doc """
  <TeiserverWeb.Microblog.MicroblogComponents.post_list post={post} />

  This is designed to show a small view of the post itself and allow for getting an idea of what is present without having to parse the entire post.
  """
  attr :posts, :list, required: true
  attr :show_full_posts, :list, required: true
  def post_list(assigns) do
     assigns =
      with %{posts: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, post_id: assigns.post_id || fn {id, _post} -> id end)
      end

    ~H"""
    <div :for={{_, post} <- @posts} id={}>
      <%= if Enum.member?(@show_full_posts, post.id) do %>
        <.post_complete post={post} />
      <% else %>
        <.post_slimline post={post} />
      <% end %>
    </div>
    """
  end

  @doc """
  <TeiserverWeb.Microblog.MicroblogComponents.post_slimline post={post} />

  This is designed to show a small view of the post itself and allow for getting an idea of what is present without having to parse the entire post.
  """
  attr :post, :map, required: true
  def post_slimline(assigns) do
    ~H"""
    <div id={"post-#{@post.id}"} class="mt-4">
      <div class="float-end">
        <div :for={tag <- @post.tags} class="d-inline-block mx-1">
          <.tag_badge tag={tag} />
        </div>
      </div>

      <h4>
        <%= @post.title %> -
        <%= TimexHelper.date_to_str(@post.inserted_at, :hms_or_ymd) %>
      </h4>
      <%= String.slice(@post.contents, 0..256) %>

      <a
        href="#"
        phx-click="show-full"
        phx-value-post-id={@post.id}
        class="d-block"
        :if={String.length(@post.contents) > 256}
      >
        Show full contents
      </a>

      <br />
    </div>
    """
  end

  @doc """
  <TeiserverWeb.Microblog.MicroblogComponents.post_complete post={post} />

  This is designed to show a small view of the post itself and allow for getting an idea of what is present without having to parse the entire post.
  """
  attr :post, :map, required: true
  def post_complete(assigns) do
    ~H"""
    <div id={"post-#{@post.id}"} class="mt-4">
      <div class="float-end">
        <div :for={tag <- @post.tags} class="d-inline-block mx-1">
          <.tag_badge tag={tag} />
        </div>
      </div>

      <h4>
        <%= @post.title %> -
        <%= TimexHelper.date_to_str(@post.inserted_at, :hms_or_ymd) %>
      </h4>
      <%= @post.contents %>

      <a
        href="#"
        phx-click="hide-full"
        phx-value-post-id={@post.id}
        class="d-block"
      >
        Show summary
      </a>
      <br />
    </div>
    """
  end

  @doc """
  <TeiserverWeb.Microblog.MicroblogComponents.post_complete post={post} />

  This is designed to show a small view of the post itself and allow for getting an idea of what is present without having to parse the entire post.
  """
  attr :post, :map, required: true
  def post_preview(assigns) do
    ~H"""
    <div id={"post-preview"} class="mt-4">
      <div class="float-end">
        <div :for={tag <- Map.get(@post, :tags, [])} class="d-inline-block mx-1">
          <.tag_badge tag={tag} />
        </div>
      </div>

      <h4>
        <%= Map.get(@post, :title, "") %> -
        <%= TimexHelper.date_to_str(Timex.now(), :hms_or_ymd) %>
      </h4>
      <%= Map.get(@post, :contents, "") %>
      <br />
    </div>
    """
  end

  @doc """
  <.tag_badge tag={tag} />
  """
  attr :tag, :map, required: true
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w()

  def tag_badge(assigns) do
    bg_colour = if assigns[:disabled] do
      "#777777"
    else
      assigns[:tag].colour
    end

    assigns = assigns
      |> assign(:bg_colour, bg_colour)

    ~H"""
    <span class="badge rounded-pill" style={"background-color: #{@bg_colour}; cursor: pointer;"} {@rest}>
      <Fontawesome.icon icon={@tag.icon} style="solid" />
      <%= @tag.name %>
    </span>
    """
  end
end
