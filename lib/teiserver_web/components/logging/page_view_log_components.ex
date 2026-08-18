defmodule TeiserverWeb.Components.Logging.PageViewLogComponents do
  @moduledoc """
  Components for PageViewLog pages
  """

  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1]

  @doc """
  <TeiserverWeb.Components.Logging.PageViewLogComponents.section_menu active={active} colour={} />
  """
  attr :colour, :string, required: true
  attr :active, :string, required: true

  def section_menu(assigns) do
    ~H"""
    <.section_menu_button
      active={@active == "index"}
      icon="fa-solid fa-bars"
      bsname={@colour}
      url={~p"/logging/page_views"}
    >
      List
    </.section_menu_button>

    <.section_menu_button
      active={@active == "perform"}
      icon="fa-solid fa-search"
      bsname={@colour}
      url={~p"/logging/page_views/search"}
    >
      Search
    </.section_menu_button>
    """
  end
end
