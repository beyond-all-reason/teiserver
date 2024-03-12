defmodule BarserverWeb.AccountComponents do
  @moduledoc false
  use BarserverWeb, :component
  import BarserverWeb.NavComponents, only: [sub_menu_button: 1]

  @doc """
  <BarserverWeb.AccountComponents.sub_menu active={active} view_colour={@view_colour} />
  """
  attr :view_colour, :string, required: true
  attr :active, :string, required: true
  attr :match_id, :integer, default: nil

  def sub_menu(assigns) do
    ~H"""
    <div class="row sub-menu">
      <.sub_menu_button
        bsname={@view_colour}
        icon={Barserver.AccountLib.icon()}
        active={@active == "profile"}
        url={~p"/profile/"}
      >
        Profile
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Barserver.Account.RelationshipLib.icon()}
        active={@active == "relationship"}
        url={~p"/account/relationship"}
      >
        Relationships
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Barserver.Config.UserConfigLib.icon()}
        active={@active == "settings"}
        url={~p"/account/settings"}
      >
        Settings
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon="fa-wrench"
        active={@active == "details"}
        url={~p"/teiserver/account/details"}
      >
        Details
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon="fa-lock"
        active={@active == "security"}
        url={~p"/teiserver/account/security"}
      >
        Security
      </.sub_menu_button>
    </div>
    """
  end
end
