defmodule TeiserverWeb.Moderation.ModerationComponents do
  @moduledoc false
  use CentralWeb, :component
  import TeiserverWeb.NavComponents, only: [sub_menu_button: 1]

  @doc """
  <TeiserverWeb.Moderation.ModerationComponents.sub_menu active={active} view_colour={@view_colour} />
  """
  attr :view_colour, :string, required: true
  attr :active, :string, required: true
  # attr :current_user, :map, required: true
  attr :match_id, :integer, default: nil
  def sub_menu(assigns) do
    ~H"""
    <div class="row sub-menu">
      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Moderation.overwatch_icon()}
        active={@active == "overwatch"}
        url={~p"/moderation/overwatch"}
      >
        Overwatch
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Moderation.ReportLib.icon()}
        active={@active == "reports"}
        url={~p"/moderation/report"}
      >
        Reports
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Moderation.ActionLib.icon()}
        active={@active == "actions"}
        url={~p"/moderation/action"}
      >
        Actions
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Moderation.BanLib.icon()}
        active={@active == "bans"}
        url={~p"/moderation/ban"}
      >
        Bans
      </.sub_menu_button>
    </div>
    """
  end
end
