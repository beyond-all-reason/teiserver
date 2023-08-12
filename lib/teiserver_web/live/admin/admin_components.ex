defmodule TeiserverWeb.Admin.AdminComponents do
  @moduledoc false
  use CentralWeb, :component
  import TeiserverWeb.NavComponents, only: [sub_menu_button: 1]

  @doc """
  <TeiserverWeb.Admin.AdminComponents.sub_menu active={active} view_colour={@view_colour} current_user={@current_user} />
  """
  attr :view_colour, :string, required: true
  attr :active, :string, required: true
  attr :current_user, :map, required: true
  attr :match_id, :integer, default: nil
  def sub_menu(assigns) do
    ~H"""
    <div class="row sub-menu">
      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Account.UserLib.icon()}
        active={@active == "users"}
        url={~p"/teiserver/admin/user"}
        :if={allow?(@current_user, "Moderator")}
      >
        Users
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Battle.MatchLib.icon()}
        active={@active == "matches"}
        url={~p"/teiserver/admin/matches/search"}
        :if={allow?(@current_user, "Reviewer")}
      >
        Matches
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Chat.LobbyMessageLib.icon()}
        active={@active == "chat"}
        url={~p"/admin/chat"}
        :if={allow?(@current_user, "Reviewer")}
      >
        Chat
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Moderation.icon()}
        active={@active == "moderation"}
        url={~p"/moderation"}
        :if={allow?(@current_user, "Reviewer")}
      >
        Moderation
      </.sub_menu_button>
    </div>
    """
  end
end
