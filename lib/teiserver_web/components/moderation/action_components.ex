defmodule TeiserverWeb.Components.Moderation.ActionComponents do
  @moduledoc """
  Components for Action pages
  """

  alias Teiserver.Account.Scope

  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1, tw_section_menu_button: 1]

  @doc """
  <TeiserverWeb.Components.Moderation.ActionComponents.section_menu active={active} colour={} />
  """
  attr :colour, :string, required: true
  attr :active, :string, required: true

  def section_menu(assigns) do
    ~H"""
    <.section_menu_button
      icon={StylingHelper.icon(:list)}
      bsname={@colour}
      url={~p"/moderation/action"}
      active={@active == "index"}
    >
      List
    </.section_menu_button>

    <.section_menu_button
      icon={StylingHelper.icon(:search)}
      bsname={@colour}
      url={~p"/moderation/action/search"}
      active={@active == "search"}
    >
      Search
    </.section_menu_button>

    <%= case @active do %>
      <% "show" -> %>
        <.section_menu_button
          icon={StylingHelper.icon(:show)}
          bsname={@colour}
          active={@active == "show"}
          url="#"
        >
          Show
        </.section_menu_button>
      <% "edit" -> %>
        <.section_menu_button
          icon={StylingHelper.icon(:edit)}
          bsname={@colour}
          active={@active == "edit"}
          url="#"
        >
          Edit
        </.section_menu_button>
      <% _ -> %>
    <% end %>
    """
  end

  @doc """
  <TeiserverWeb.Components.Moderation.ActionComponents.section_menu
    active="some-link"
    scope={@scope}
  />
  """
  attr :scope, Scope, required: true
  attr :active, :string, required: true

  def tw_section_menu(assigns) do
    ~H"""
    <div role="tablist" class="tabs tabs-box">
      <.tw_section_menu_button
        icon={StylingHelper.icon(:list)}
        url={~p"/moderation/action"}
        active={@active == "index"}
      >
        List
      </.tw_section_menu_button>

      <.tw_section_menu_button
        icon={StylingHelper.icon(:search)}
        url={~p"/moderation/action/search"}
        active={@active == "search"}
      >
        Search
      </.tw_section_menu_button>

      <.tw_section_menu_button
        :if={@active == "show"}
        icon={StylingHelper.icon(:show)}
        url="#"
        active={true}
      >
        Show
      </.tw_section_menu_button>

      <.tw_section_menu_button
        :if={@active == "edit"}
        icon={StylingHelper.icon(:edit)}
        url="#"
        active={true}
      >
        Edit
      </.tw_section_menu_button>

      <.tw_section_menu_button
        :if={@active == "smurf-link"}
        active={true}
        icon="fa-solid fa-code-compare"
        url="#"
      >
        Smurf link
      </.tw_section_menu_button>
    </div>
    """
  end
end
