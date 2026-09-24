defmodule TeiserverWeb.ModerationLive.ToolsComponents do
  @moduledoc false
  alias Teiserver.Account.Scope

  use TeiserverWeb, :component

  import TeiserverWeb.NavComponents, only: [section_menu_link: 1]

  @doc """
  <ToolsComponents.section_menu
    active="some-link"
    scope={@scope}
  />

  <ToolsComponents.section_menu
    active="some-link"
    scope={@scope}
  >
    <:left_links>
      <li>Link goes here</li>
    </:left_links>
    <:right_links>
      <li>Link goes here</li>
    </:right_links>
  </ToolsComponents.section_menu>
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
          url={~p"/moderation"}
        >
          Moderation
        </.section_menu_link>

        <.section_menu_link
          icon="fa-code-compare"
          url={~p"/moderation/tools/time_compare"}
          active={@active == "time_compare"}
        >
          Time compare
        </.section_menu_link>

        <.section_menu_link
          icon="fa-question"
          url={~p"/moderation/tools/gdpr_restore"}
          active={@active == "gdpr_restore"}
        >
          GDPR restore
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
