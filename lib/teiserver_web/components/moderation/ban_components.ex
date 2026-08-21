defmodule TeiserverWeb.Components.Moderation.BanComponents do
  @moduledoc """
  Components for Ban pages
  """

  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1]

  @doc """
  <TeiserverWeb.Components.Moderation.BanComponents.section_menu active={active} colour={} />
  """
  attr :colour, :string, required: true
  attr :active, :string, required: true

  def section_menu(assigns) do
    ~H"""
    <.section_menu_button
      active={@active == "index"}
      icon={StylingHelper.icon(:list)}
      bsname={@colour}
      url={~p"/moderation/ban"}
    >
      List
    </.section_menu_button>

    <.section_menu_button
      active={@active == "search"}
      icon={StylingHelper.icon(:search)}
      bsname={@colour}
      url={~p"/moderation/ban?search=true"}
    >
      Search
    </.section_menu_button>

    <%= case @active do %>
      <% "show" -> %>
        <.section_menu_button
          active={@active == "show"}
          icon={StylingHelper.icon(:show)}
          bsname={@colour}
          url="#"
        >
          Show
        </.section_menu_button>
      <% "edit" -> %>
        <.section_menu_button
          active={@active == "edit"}
          icon={StylingHelper.icon(:edit)}
          bsname={@colour}
          url="#"
        >
          Edit
        </.section_menu_button>
      <% _ -> %>
    <% end %>
    """
  end
end
