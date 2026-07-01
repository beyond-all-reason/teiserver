defmodule TeiserverWeb.Moderation.ModerationComponents do
  @moduledoc false
  alias Teiserver.Account.Auth
  alias Teiserver.Account.User

  use TeiserverWeb, :component

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

  @doc """
  Displays (if appropriate) a warning that this user has some form of VIP status and to check with senior moderators/community management if this needs to be handled in a certain way.

  <.action_warning user={@user} />
  """
  attr :user, User, required: true

  def action_warning(assigns) do
    ~H"""
    <div :if={Auth.vip?(@user)} class="alert alert-info">
      This user has VIP or Contributor credentials. Please check with senior moderators and/or community management if any additional communication needs to take place around this action.
    </div>
    """
  end
end
