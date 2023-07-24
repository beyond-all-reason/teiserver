defmodule TeiserverWeb.Moderation.ModerationComponents do
  @moduledoc false
  use CentralWeb, :component
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1]

  @doc """
  <TeiserverWeb.Moderation.ModerationComponents.section_menu active={active} bsname={} />
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
      url={~p"/teiserver/battle/matches"}
    >
      List
    </.section_menu_button>

    <.section_menu_button
      bsname={@view_colour}
      icon={Teiserver.Account.RatingLib.icon()}
      active={@active == "ratings"}
      url={~p"/teiserver/battle/ratings"}
    >
      Ratings
    </.section_menu_button>

    <.section_menu_button
      bsname={@view_colour}
      icon={StylingHelper.icon(:chart)}
      active={@active == "progression"}
      url={~p"/teiserver/battle/progression"}
    >
      Progression
    </.section_menu_button>

    <.section_menu_button
      :if={@active == "show"}
      bsname={@view_colour}
      icon={StylingHelper.icon(:detail)}
      active={true}
      url="#"
    >
      Match details
    </.section_menu_button>

    <div class="float-end">
      <.section_menu_button
        :if={@match_id != nil and allow?(@current_user, "Moderator")}
        bsname={@view_colour}
        icon={StylingHelper.icon(:admin)}
        active={false}
        url={~p"/teiserver/admin/matches/#{@match_id}"}
      >
        Admin view
      </.section_menu_button>
    </div>
    """
  end
end
