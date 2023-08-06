defmodule TeiserverWeb.AccountComponents do
  @moduledoc false
  use CentralWeb, :component
  import TeiserverWeb.NavComponents, only: [sub_menu_button: 1]

  @doc """
  <TeiserverWeb.AccountComponents.sub_menu active={active} view_colour={@view_colour} />
  """
  attr :view_colour, :string, required: true
  attr :active, :string, required: true
  attr :match_id, :integer, default: nil
  def sub_menu(assigns) do
    ~H"""
    <div class="row sub-menu">
      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.AccountLib.icon()}
        active={@active == "profile"}
        url={~p"/teiserver/profile"}
      >
        Profile
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Account.RelationshipLib.icon()}
        active={@active == "relationship"}
        url={~p"/account/relationship"}
      >
        Relationships
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Config.UserConfigLib.icon()}
        active={@active == "preferences"}
        url={~p"/teiserver/account/preferences"}
      >
        Settings
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