defmodule BarserverWeb.Account.RelationshipComponents do
  @moduledoc false
  use BarserverWeb, :component
  import BarserverWeb.NavComponents, only: [section_menu_button: 1]

  @doc """
  <BarserverWeb.Account.RelationshipComponents.section_menu active={active} bsname={} />
  """
  attr :view_colour, :string, required: true
  attr :active, :string, required: true
  attr :current_user, :map, required: true
  attr :match_id, :integer, default: nil

  def section_menu(assigns) do
    ~H"""
    <.section_menu_button
      bsname={@view_colour}
      icon={StylingHelper.icon(:list)}
      active={@active == "index"}
      url={~p"/account/relationship"}
    >
      List
    </.section_menu_button>
    """
  end
end
