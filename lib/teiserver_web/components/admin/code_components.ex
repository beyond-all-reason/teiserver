defmodule TeiserverWeb.Components.Admin.CodeComponents do
  @moduledoc """
  Components for Code pages
  """

  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1]

  @doc """
  <TeiserverWeb.Components.Admin.CodeComponents.section_menu active={active} colour={} />
  """
  attr :colour, :string, required: true
  attr :active, :string, required: true

  def section_menu(assigns) do
    ~H"""
    <.section_menu_button
      active={@active == "index"}
      icon="fa-solid fa-bars"
      bsname={@colour}
      url={~p"/teiserver/admin/codes"}
    >
      List
    </.section_menu_button>

    <.section_menu_button
      active={@active == "new"}
      icon="fa-solid fa-plus"
      bsname={@colour}
      url={~p"/teiserver/admin/codes/new"}
    >
      New
    </.section_menu_button>
    """
  end
end
