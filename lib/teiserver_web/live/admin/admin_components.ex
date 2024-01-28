defmodule BarserverWeb.Admin.AdminComponents do
  @moduledoc false
  use BarserverWeb, :component
  import BarserverWeb.NavComponents, only: [sub_menu_button: 1]

  @doc """
  <BarserverWeb.Admin.AdminComponents.sub_menu active={active} view_colour={@view_colour} current_user={@current_user} />
  """
  attr :view_colour, :string, required: true
  attr :active, :string, required: true
  attr :current_user, :map, required: true
  attr :match_id, :integer, default: nil

  def sub_menu(assigns) do
    ~H"""
    <div class="row sub-menu">
      <.sub_menu_button
        :if={allow?(@current_user, "Moderator")}
        bsname={@view_colour}
        icon={Barserver.Account.UserLib.icon()}
        active={@active == "users"}
        url={~p"/teiserver/admin/user"}
      >
        Users
      </.sub_menu_button>

      <.sub_menu_button
        :if={allow?(@current_user, "Reviewer")}
        bsname={@view_colour}
        icon={Barserver.Battle.MatchLib.icon()}
        active={@active == "matches"}
        url={~p"/teiserver/admin/matches/search"}
      >
        Matches
      </.sub_menu_button>

      <.sub_menu_button
        :if={allow?(@current_user, "Reviewer")}
        bsname={@view_colour}
        icon={Barserver.Chat.LobbyMessageLib.icon()}
        active={@active == "chat"}
        url={~p"/admin/chat"}
      >
        Chat
      </.sub_menu_button>

      <.sub_menu_button
        :if={allow?(@current_user, "Reviewer")}
        bsname={@view_colour}
        icon={Barserver.Moderation.icon()}
        active={@active == "moderation"}
        url={~p"/moderation"}
      >
        Moderation
      </.sub_menu_button>
    </div>
    """
  end
end
