defmodule TeiserverWeb.AdminLive.SiteConfigComponents do
  @moduledoc false
  alias Teiserver.Account.Scope

  use TeiserverWeb, :component

  import TeiserverWeb.CoreComponents, only: [simple_form: 1, input_tw: 1]
  import TeiserverWeb.NavComponents, only: [section_menu_link: 1]

  @doc """
  <TeiserverWeb.Admin.SiteConfigComponents.search_form
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
      phx-change="update-search"
      phx-submit="update-search"
      id="site_config-search-form"
    >
      <div class="grid grid-flow-row-dense grid-cols-3">
        <div class="m-2">
          <.input_tw
            type="text"
            field={@form[:name]}
            label=""
            placeholder="Search by name or key"
          />
        </div>
      </div>
    </.simple_form>
    """
  end

  @doc """
  <SiteConfigComponents.section_menu
    active="some-link"
    scope={@scope}
  />

  <SiteConfigComponents.section_menu
    active="some-link"
    scope={@scope}
  >
    <:left_links>
      <li>Link goes here</li>
    </:left_links>
    <:right_links>
      <li>Link goes here</li>
    </:right_links>
  </SiteConfigComponents.section_menu>
  """
  attr :scope, Scope, required: true
  attr :active, :string, required: true
  slot :extra_links, doc: "Slot for extra links for the left side of the menu bar"
  slot :inner_block, doc: "Slot for content for the right side of the menu bar"

  def section_menu(assigns) do
    ~H"""
    <div class="section-menu-bar">
      <ul class="menu menu-horizontal">
        <.section_menu_link
          icon="fa-arrow-left"
          url={~p"/admin"}
        >
          Admin
        </.section_menu_link>

        <.section_menu_link
          icon={StylingHelper.icon(:list)}
          url={~p"/admin/site_config"}
          active={@active == "list"}
        >
          List
        </.section_menu_link>

        <.section_menu_link
          :if={@active == "show"}
          icon={StylingHelper.icon(:show)}
          url="#"
          active={true}
        >
          Show
        </.section_menu_link>

        {render_slot(@extra_links)}
      </ul>

      <div class="section-menu-bar-inner_block">
        <ul class="menu menu-horizontal">
          {render_slot(@inner_block)}
        </ul>
      </div>
    </div>
    """
  end
end
