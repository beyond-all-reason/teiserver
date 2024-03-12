defmodule BarserverWeb.Battle.BattleComponents do
  @moduledoc false
  use BarserverWeb, :component
  import BarserverWeb.NavComponents, only: [sub_menu_button: 1]

  @doc """
  <BarserverWeb.Battle.BattleComponents.sub_menu active={active} view_colour={@view_colour} />
  """
  attr :view_colour, :string, required: true
  attr :active, :string, required: true
  attr :match_id, :integer, default: nil

  def sub_menu(assigns) do
    ~H"""
    <div class="row sub-menu">
      <.sub_menu_button
        bsname={@view_colour}
        icon={Barserver.Lobby.icon()}
        active={@active == "lobbies"}
        url={~p"/battle/lobbies"}
      >
        Lobbies
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Barserver.Game.QueueLib.icon()}
        active={@active == "matchmaking"}
        url={~p"/teiserver/matchmaking/queues"}
      >
        Matchmaking
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Barserver.Account.PartyLib.icon()}
        active={@active == "parties"}
        url={~p"/teiserver/account/parties"}
      >
        Parties
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Barserver.Battle.MatchLib.icon()}
        active={@active == "matches"}
        url={~p"/battle"}
      >
        Matches
      </.sub_menu_button>

      <.sub_menu_button
        bsname={@view_colour}
        icon={Barserver.Account.RatingLib.icon()}
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
