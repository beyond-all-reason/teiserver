defmodule TeiserverWeb.Components.Logging.AuditLogComponents do
  @moduledoc """
  Components for AuditLog pages
  """

  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1]

  @doc """
  <TeiserverWeb.Components.Logging.AuditLogComponents.section_menu active={active} colour={} />
  """
  attr :colour, :string, required: true
  attr :active, :string, required: true

  def section_menu(assigns) do
    ~H"""
    <.section_menu_button
      active={@active == "index"}
      icon="fa-solid fa-bars"
      bsname={@colour}
      url={~p"/logging/audit"}
    >
      List
    </.section_menu_button>

    <.section_menu_button
      active={@active == "perform"}
      icon="fa-solid fa-search"
      bsname={@colour}
      url={~p"/logging/audit/search"}
    >
      Search
    </.section_menu_button>
    """
  end
end
