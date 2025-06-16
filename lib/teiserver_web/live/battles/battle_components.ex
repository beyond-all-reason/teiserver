defmodule TeiserverWeb.Battle.BattleComponents do
  @moduledoc false
  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [sub_menu_button: 1]

  @doc """
  <TeiserverWeb.Battle.BattleComponents.sub_menu active={active} view_colour={@view_colour} />
  """
  attr :view_colour, :string, required: true
  attr :active, :string, required: true
  attr :match_id, :integer, default: nil

  def sub_menu(assigns) do
    ~H"""
    <div class="row sub-menu">
      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Lobby.icon()}
        active={@active == "lobbies"}
        url={~p"/battle/lobbies"}
      >
        Lobbies
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Account.PartyLib.icon()}
        active={@active == "parties"}
        url={~p"/teiserver/account/parties"}
      >
        Parties
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Battle.MatchLib.icon()}
        active={@active == "matches"}
        url={~p"/battle"}
      >
        Matches
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Teiserver.Account.RatingLib.icon()}
        active={@active == "ratings"}
        url={~p"/battle/ratings/leaderboard"}
      >
        Leaderboard
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon="fa-trophy"
        active={@active == "tournaments"}
        url={~p"/tournament/lobbies"}
      >
        Tournaments
      </.sub_menu_button>
    </div>
    """
  end
end
