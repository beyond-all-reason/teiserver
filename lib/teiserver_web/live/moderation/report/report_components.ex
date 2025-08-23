defmodule TeiserverWeb.Moderation.ReportComponents do
  @moduledoc false
  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1]

  @doc """
  <TeiserverWeb.Moderation.ReportComponents.section_menu
    active={active}
    view_colour={@view_colour}
    current_user={@current_user} />

  or

  <TeiserverWeb.Moderation.ReportComponents.section_menu
    active={active}
    view_colour={@view_colour}
    current_user={@current_user}
  >
    Content here
  </TeiserverWeb.Moderation.ReportComponents.section_menu>
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
      url={~p"/moderation/report"}
    >
      List
    </.section_menu_button>

    <.section_menu_button
      bsname={@view_colour}
      icon={StylingHelper.icon(:search)}
      active={@active == "search"}
      url={~p"/moderation/report?search=true"}
    >
      Search
    </.section_menu_button>

    <.section_menu_button
      :if={@active == "show"}
      bsname={@view_colour}
      icon={StylingHelper.icon(:show)}
      active={true}
      url="#"
    >
      Show
    </.section_menu_button>

    <.section_menu_button
      :if={@active == "user"}
      bsname={@view_colour}
      icon={StylingHelper.icon(:user)}
      active={true}
      url="#"
    >
      User
    </.section_menu_button>

    <.section_menu_button
      :if={@active == "edit"}
      bsname={@view_colour}
      icon={StylingHelper.icon(:edit)}
      active={true}
      url="#"
    >
      Edit
    </.section_menu_button>

    {render_slot(@inner_block)}
    """
  end
end
