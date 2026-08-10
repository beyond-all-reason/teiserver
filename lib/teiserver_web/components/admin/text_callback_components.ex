defmodule TeiserverWeb.Components.Admin.TextCallbackComponents do
  @moduledoc """
  Components for TextCallback pages
  """

  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1]

  @doc """
  <TeiserverWeb.Components.Admin.TextCallbackComponents.section_menu active={active} colour={} />
  """
  attr :colour, :string, required: true
  attr :active, :string, required: true

  def section_menu(assigns) do
    ~H"""
    <.section_menu_button
      active={@active == "index"}
      icon="fa-solid fa-bars"
      bsname={@colour}
      url={~p"/admin/text_callbacks"}
    >
      List
    </.section_menu_button>

    <.section_menu_button
      active={@active == "new"}
      icon="fa-solid fa-plus"
      bsname={@colour}
      url={~p"/admin/text_callbacks/new"}
    >
      New
    </.section_menu_button>
    """
  end
end
