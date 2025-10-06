defmodule TeiserverWeb.Battle.MatchComponents do
  @moduledoc false
  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1]

  @doc """
  <TeiserverWeb.Battle.MatchComponents.section_menu active={active} bsname={} />
  """
  attr :view_colour, :string, required: true
  attr :active, :string, required: true
  attr :current_user, :map, required: true
  attr :match_id, :integer, default: nil
  attr :replay, :string, default: nil

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
      icon={Teiserver.Account.RatingLib.icon()}
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
        :if={allow?(@current_user, "Overwatch")}
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
        :if={@replay != nil}
        bsname={@view_colour}
        icon={StylingHelper.icon(:replay)}
        active={false}
        url={@replay}
      >
        Replay
      </.section_menu_button>
    </div>
    """
  end
end
