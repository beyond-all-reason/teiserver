defmodule TeiserverWeb.Components.Logging.AggregateViewLogComponents do
  @moduledoc """
  Components for AggregateViewLog pages
  """

  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1]

  @doc """
  <TeiserverWeb.Components.Logging.AggregateViewLogComponents.section_menu active={active} colour={} />
  """
  attr :colour, :string, required: true
  attr :active, :string, required: true

  def section_menu(assigns) do
    ~H"""
    <.section_menu_button
      active={@active == "index"}
      icon="fa-solid fa-bars"
      bsname={@colour}
      url={~p"/logging/aggregate_views"}
    >
      List
    </.section_menu_button>

    <.section_menu_button
      active={@active == "perform"}
      icon="fa-solid fa-sync"
      bsname={@colour}
      url={~p"/logging/aggregate_views/perform"}
    >
      Perform conversion
    </.section_menu_button>
    """
  end
end
