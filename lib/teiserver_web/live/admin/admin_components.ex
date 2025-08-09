defmodule TeiserverWeb.Admin.AdminComponents do
  @moduledoc false
  use TeiserverWeb, :component
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
        :if={allow?(@current_user, "Moderator")}
        bsname={@view_colour}
        icon={Teiserver.Account.UserLib.icon()}
        active={@active == "users"}
        url={~p"/teiserver/admin/user"}
      >
        Users
      </.sub_menu_button>

      <.sub_menu_button
        :if={allow?(@current_user, "Reviewer")}
        bsname={@view_colour}
        icon={Teiserver.Battle.MatchLib.icon()}
        active={@active == "matches"}
        url={~p"/teiserver/admin/matches/search"}
      >
        Matches
      </.sub_menu_button>

      <.sub_menu_button
        :if={allow?(@current_user, "Reviewer")}
        bsname={@view_colour}
        icon={Teiserver.Chat.LobbyMessageLib.icon()}
        active={@active == "chat"}
        url={~p"/admin/chat"}
      >
        Chat
      </.sub_menu_button>

      <.sub_menu_button
        :if={allow?(@current_user, "Reviewer")}
        bsname={@view_colour}
        icon={Teiserver.Moderation.icon()}
        active={@active == "moderation"}
        url={~p"/moderation"}
      >
        Moderation
      </.sub_menu_button>

      <.sub_menu_button
        :if={allow?(@current_user, "Admin")}
        bsname={@view_colour}
        icon="fa-solid fa-users"
        active={@active == "matchmaking"}
        url={~p"/admin/matchmaking"}
      >
        Matchmaking
      </.sub_menu_button>
    </div>
    """
  end
end
