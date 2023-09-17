defmodule TeiserverWeb.Moderation.OverwatchComponents do
  @moduledoc false
  use CentralWeb, :component
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1]

  @doc """
  <TeiserverWeb.Moderation.OverwatchComponents.section_menu active={active} bsname={} />
  """
  attr :view_colour, :string, required: true
  attr :active, :string, required: true
  attr :current_user, :map, required: true
  attr :match_id, :integer, default: nil
  slot :inner_block

  def section_menu(assigns) do
    ~H"""
    <.section_menu_button
      bsname={@view_colour}
      icon={StylingHelper.icon(:list)}
      active={@active == "index"}
      url={~p"/moderation/overwatch"}
    >
      Reports
    </.section_menu_button>

    <.section_menu_button
      :if={@active == "show"}
      bsname={@view_colour}
      icon={StylingHelper.icon(:show)}
      active={true}
      url="#"
    >
      Report group detail
    </.section_menu_button>

    <%= render_slot(@inner_block) %>
    """
  end
end
