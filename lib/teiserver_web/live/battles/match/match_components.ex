defmodule BarserverWeb.Battle.MatchComponents do
  @moduledoc false
  use BarserverWeb, :component
  import BarserverWeb.NavComponents, only: [section_menu_button: 1]

  @doc """
  <BarserverWeb.Battle.MatchComponents.section_menu active={active} bsname={} />
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
      url={~p"/battle"}
    >
      List
    </.section_menu_button>

    <.section_menu_button
      bsname={@view_colour}
      icon={Barserver.Account.RatingLib.icon()}
      active={@active == "ratings"}
      url={~p"/battle/ratings"}
    >
      Ratings
    </.section_menu_button>

    <.section_menu_button
      bsname={@view_colour}
      icon={StylingHelper.icon(:chart)}
      active={@active == "progression"}
      url={~p"/battle/progression"}
    >
      Progression
    </.section_menu_button>

    <%= if @match_id do %>
      <.section_menu_button
        bsname={@view_colour}
        icon={StylingHelper.icon(:detail)}
        active={@active == "show"}
        url={~p"/battle/#{@match_id}"}
      >
        Match details
      </.section_menu_button>

      <.section_menu_button
        :if={allow?(@current_user, "Reviewer")}
        bsname={@view_colour}
        icon={StylingHelper.icon(:chat)}
        active={@active == "chat"}
        url={~p"/battle/chat/#{@match_id}"}
      >
        Chat
      </.section_menu_button>
    <% end %>

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
