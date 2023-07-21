defmodule TeiserverWeb.Battle.MatchComponents do
  @moduledoc false
  use CentralWeb, :component
  import CentralWeb.CoreComponents, only: [section_menu_button: 1]

  @doc """
  <TeiserverWeb.Battle.MatchComponents.section_menu active={active} bsname={} />
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
      :if={@active == "show"}
      bsname={@view_colour}
      icon={Central.Helpers.StylingHelper.icon(:detail)}
      active={true}
      url="#"
    >
      Match details
    </.section_menu_button>

    <div class="float-end">
      <.section_menu_button
        :if={@match_id != nil and allow?(@current_user, "Moderator")}
        bsname={@view_colour}
        icon={Central.Helpers.StylingHelper.icon(:admin)}
        active={false}
        url={~p"/teiserver/admin/matches/#{@match_id}"}
      >
        Admin view
      </.section_menu_button>
    </div>
    """
  end
end
