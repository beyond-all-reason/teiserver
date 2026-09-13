defmodule TeiserverWeb.ModerationLive.UserComponents do
  @moduledoc false
  alias Teiserver.Account.Auth
  alias Teiserver.Account.Scope
  alias Teiserver.Account.User
  alias Teiserver.Moderation.ActionLib

  use TeiserverWeb, :component

  import TeiserverWeb.CoreComponents, only: [simple_form: 1, input_tw: 1]
  import TeiserverWeb.NavComponents, only: [section_menu_link: 1]

  @doc """
  <TeiserverWeb.Moderation.UserComponents.search_form
    :if={assigns[:search]}
    params={@search}
  />

  You will need to implement the following event handlers:

  handle_event("update-search", params, %Socket{} = socket)
  handle_event("validate-search", params, %Socket{} = socket)
  handle_event("reset-search", _params, %Socket{} = socket)
  """
  attr :params, :map, required: true
  attr :changed?, :boolean, default: false

  def search_form(%{params: params} = assigns) do
    form = to_form(params)

    assigns =
      assigns
      |> assign(form: form)

    ~H"""
    <.simple_form
      for={@form}
      phx-change="validate-search"
      phx-submit="update-search"
      id="user-search-form"
    >
      <div class="grid grid-flow-row-dense grid-cols-3">
        <div class="m-2">
          <.input_tw
            type="text"
            field={@form[:name]}
            label="Name"
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="select"
            field={@form[:order_by]}
            label="Order by"
            options={["Newest first", "Oldest first", "Alphabetical (A-Z)", "Alphabetical (Z-A)"]}
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="select"
            field={@form[:page_size]}
            label="Records per page"
            options={[5, 10, 25, 50, 100]}
          />
        </div>
      </div>

      <div class="float-right">
        <div phx-click="reset-search" class="btn-reset-form">
          <Fontawesome.icon icon="rotate-left" style="regular" /> Reset
        </div>
        <button class={["btn btn-primary", not @changed? && "btn-soft"]}>
          <Fontawesome.icon icon="search" style="regular" /> Update results
        </button>
      </div>
    </.simple_form>
    """
  end

  @doc """
  <UserComponents.section_menu
    active="some-link"
    scope={@scope}
  />

  <UserComponents.section_menu
    active="some-link"
    scope={@scope}
  >
    <:left_links>
      <li>Link goes here</li>
    </:left_links>
    <:right_links>
      <li>Link goes here</li>
    </:right_links>
  </UserComponents.section_menu>
  """
  attr :scope, Scope, required: true
  attr :active, :string, required: true
  attr :user, User, default: nil
  slot :extra_links, doc: "Slot for extra links for the left side of the menu bar"
  slot :inner_block, doc: "Slot for content for the right side of the menu bar"

  def section_menu(assigns) do
    ~H"""
    <div class="section-menu-bar">
      <ul class="menu menu-horizontal">
        <.section_menu_link
          icon={StylingHelper.icon(:list)}
          url={~p"/moderation/users"}
          active={@active == "list"}
        >
          List
        </.section_menu_link>

        <.section_menu_link
          :if={@user}
          icon={StylingHelper.icon(:show)}
          url={~p"/moderation/users/#{@user.id}"}
          active={@active == "show"}
        >
          Show
        </.section_menu_link>

        <.section_menu_link
          :if={@active == "list"}
          icon={StylingHelper.icon(:list)}
          url={~p"/teiserver/admin/user"}
          active={false}
        >
          Old list
        </.section_menu_link>

        <.section_menu_link
          :if={@active == "action"}
          icon="bolt-lightning"
          url="#"
          active={true}
        >
          Action
        </.section_menu_link>

        {render_slot(@extra_links)}
      </ul>

      <div class="section-menu-bar-inner_block">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  <TeiserverWeb.Moderation.UserComponents.status_icon user={user} />
  """
  attr :user, User, required: true

  def status_icon(%{user: %User{} = user} = assigns) do
    restrictions = user.restrictions || []

    ban_status =
      cond do
        Enum.member?(restrictions, "Permanently banned") -> "banned"
        Enum.member?(restrictions, "Login") -> "suspended"
        true -> ""
      end

    icons =
      [
        if(assigns.user.smurf_of_id != nil,
          do: {"primary", ActionLib.action_icon("Smurf")}
        ),
        if(Enum.member?(user.roles, "Smurfer"),
          do: {"info2", "fa-solid fa-arrows-split-up-and-left"}
        ),
        if(ban_status == "banned",
          do: {"danger2", ActionLib.action_icon("Ban")}
        ),
        if(ban_status == "suspended",
          do: {"danger", ActionLib.action_icon("Suspend")}
        ),
        if(Enum.member?(restrictions, "All chat"),
          do: {"danger", ActionLib.action_icon("Mute")}
        ),
        if(Enum.member?(restrictions, "Warning reminder"),
          do: {"warning", ActionLib.action_icon("Warn")}
        ),
        if(Auth.trusted?(user), do: {"", "fa-solid fa-check"}),
        if(not Enum.member?(user.roles, "Verified"),
          do: {"info", "fa-solid fa-user-secret"}
        )
      ]
      |> Enum.reject(&(&1 == nil))

    status_icon_list(%{icons: icons})
  end

  defp status_icon_list(assigns) do
    ~H"""
    <div :for={{colour, icon} <- @icons} class="d-inline-block">
      <i class={"fa-fw text-#{colour} #{icon}"}></i>
    </div>
    """
  end
end
