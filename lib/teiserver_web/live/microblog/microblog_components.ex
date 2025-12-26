defmodule TeiserverWeb.MicroblogComponents do
  @moduledoc false
  use TeiserverWeb, :component
  alias Teiserver.Helper.TimexHelper
  import TeiserverWeb.NavComponents, only: [sub_menu_button: 1]

  @doc """
  <TeiserverWeb.MicroblogComponents.sub_menu active={active} view_colour={@view_colour} />
  """
  attr :view_colour, :string, required: true
  attr :active, :string, required: true
  attr :match_id, :integer, default: nil
  attr :current_user, :map, required: true

  def sub_menu(assigns) do
    ~H"""
    <div class="row sub-menu">
      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Microblog.icon()}
        active={@active == "home"}
        url={~p"/microblog"}
      >
        Blog
      </.sub_menu_button>

      <.sub_menu_button
        :if={@current_user}
        bsname={@view_colour}
        icon="fa-cog"
        active={@active == "preferences"}
        url={~p"/microblog/preferences"}
      >
        Preferences
      </.sub_menu_button>

      <.sub_menu_button
        :if={allow?(@current_user, "Blog helper")}
        bsname={@view_colour}
        icon={Teiserver.Microblog.PostLib.icon()}
        active={@active == "posts"}
        url={~p"/microblog/admin/posts"}
      >
        Posts
      </.sub_menu_button>

      <.sub_menu_button
        :if={allow?(@current_user, "Server")}
        bsname={@view_colour}
        icon={Teiserver.Microblog.TagLib.icon()}
        active={@active == "tags"}
        url={~p"/microblog/admin/tags"}
      >
        Tags
      </.sub_menu_button>

      <.sub_menu_button
        :if={allow?(@current_user, "Server")}
        bsname={@view_colour}
        icon="fa-upload"
        active={@active == "uplaods"}
        url={~p"/microblog/admin/uploads"}
      >
        Uploads
      </.sub_menu_button>
    </div>
    """
  end

  @doc """
  <TeiserverWeb.MicroblogComponents.post_complete post={post} />

  This is designed to show a small view of the post itself and allow for getting an idea of what is present without having to parse the entire post.
  """
  attr :post, :map, required: true

  def post_preview_small(assigns) do
    ~H"""
    <div id="post-preview-small" class="mt-4">
      <hr />
      <h5 style="text-align: center;">--- Small preview ---</h5>

      <div class="float-end">
        <div :for={tag <- Map.get(@post, :tags, [])} class="d-inline-block mx-1">
          <.tag_badge tag={tag} />
        </div>
      </div>

      <h4>
        {Map.get(@post, :title, "")} - {TimexHelper.date_to_str(Timex.now(), :hms_or_ymd)}
      </h4>
      {Map.get(@post, :contents, "")
      |> String.split("\n\n")
      |> hd()
      |> MDEx.to_html!()
      |> Phoenix.HTML.raw()}
      <br />
    </div>
    """
  end

  attr :post, :map, required: true

  def post_preview_full(assigns) do
    ~H"""
    <div id="post-preview-full" class="mt-4">
      <hr />
      <h5 style="text-align: center;">--- Full preview ---</h5>

      <div class="float-end">
        <div :for={tag <- Map.get(@post, :tags, [])} class="d-inline-block mx-1">
          <.tag_badge tag={tag} />
        </div>
      </div>

      <h4>
        {Map.get(@post, :title, "")} - {TimexHelper.date_to_str(Timex.now(), :hms_or_ymd)}
      </h4>
      {Map.get(@post, :contents, "") |> MDEx.to_html!() |> Phoenix.HTML.raw()}
      <br />
    </div>
    """
  end

  @doc """
  <.tag_badge tag={tag} />
  """
  attr :tag, :map, required: true
  attr :disabled, :boolean, default: false
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w()

  def tag_badge(assigns) do
    bg_colour =
      if assigns[:disabled] do
        "#777777"
      else
        assigns[:tag].colour
      end

    assigns =
      assigns
      |> assign(:bg_colour, bg_colour)

    ~H"""
    <span
      class={"badge rounded-pill mx-1 #{@class}"}
      style={"background-color: #{@bg_colour}; cursor: pointer;"}
      {@rest}
    >
      <Fontawesome.icon icon={@tag.icon} style="solid" />
      {@tag.name}
    </span>
    """
  end

  @doc """
  <TeiserverWeb.MicroblogComponents.poll_result post={@post} />
  """
  attr :post, :map, required: true

  def poll_result(assigns) do
    # This allows us to show empty results even in the event of the cache being empty (e.g. there are no poll responses yet)
    responses =
      if assigns[:post].poll_result_cache do
        assigns[:post].poll_result_cache
        |> Enum.to_list()
        |> Enum.sort_by(fn {_, v} -> v end, &>=/2)
      else
        assigns[:post].poll_choices
        |> Enum.map(fn v -> {v, 0} end)
      end

    assigns =
      assigns
      |> assign(:responses, responses)

    ~H"""
    <div>
      <div :for={{choice, result} <- @responses}>
        {choice} - {result}
      </div>
    </div>
    """
  end

  @doc """
  <TeiserverWeb.MicroblogComponents.poll_response post={@post} response={@response} />
  Don't forget to implement
    handle_event("poll-choice", %{"choice" => choice}, socket)
  """
  attr :post, :map, required: true
  attr :response, :map

  def poll_response(assigns) do
    selected =
      if assigns[:response] do
        assigns[:response].response
      else
        nil
      end

    assigns =
      assigns
      |> assign(:selected, selected)

    ~H"""
    <div>
      <h4>Vote in the poll</h4>
      <div
        :for={choice <- @post.poll_choices}
        phx-click="poll-choice"
        phx-value-choice={choice}
        class={"btn btn-sm #{if @selected == choice, do: "btn-primary", else: "btn-outline-primary"} me-2"}
      >
        {choice}
      </div>
    </div>
    """
  end
end
