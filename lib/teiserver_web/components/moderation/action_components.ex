defmodule TeiserverWeb.Components.Moderation.ActionComponents do
  @moduledoc """
  Components for Action pages
  """

  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1]

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
end
