defmodule TeiserverWeb.Account.ProfileComponents do
  @moduledoc false
  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [tab_header: 1, tab_nav: 1]

  @doc """
  <TeiserverWeb.Account.ProfileComponents.profile_tabs tab="overview" userid={@userid} self={@current_user && @current_user.id == @userid} />
  """
  attr :tab, :string, required: true
  attr :userid, :integer, required: true
  attr :profile_permissions, :list, default: []
  attr :current_user, :map, required: true

  def profile_tabs(assigns) do
    ~H"""
    <div class="row mt-2 mb-3">
      <div class="col" id="nav-col">
        <.tab_header>
          <.tab_nav url={~p"/profile/#{@userid}/overview"} selected={@tab == "overview"}>
            <Fontawesome.icon icon_atom={:summary} style="solid" /> Overview
          </.tab_nav>

          <.tab_nav url={~p"/profile/#{@userid}/matches"} selected={@tab == "matches"}>
            <Fontawesome.icon icon={Teiserver.Battle.MatchLib.icon()} style="solid" /> Matches
          </.tab_nav>

          <.tab_nav url={~p"/profile/#{@userid}/accolades"} selected={@tab == "accolades"}>
            <Fontawesome.icon icon={Teiserver.Account.AccoladeLib.icon()} style="solid" /> Accolades
          </.tab_nav>

          <.tab_nav url={~p"/profile/#{@userid}/achievements"} selected={@tab == "achievements"}>
            <Fontawesome.icon icon={Teiserver.Game.AchievementTypeLib.icon()} style="solid" />
            Achievements
          </.tab_nav>

          <.tab_nav url={~p"/profile/#{@userid}/playtime"} selected={@tab == "playtime"}>
            <Fontawesome.icon icon="fa-timer" style="solid" /> Playtime
          </.tab_nav>

          <.tab_nav
            :if={Enum.member?(@profile_permissions, :self)}
            url={~p"/profile/#{@userid}/appearance"}
            selected={@tab == "appearance"}
          >
            <Fontawesome.icon icon="icons" style="solid" /> Appearance
          </.tab_nav>

          <.tab_nav
            :if={
              not Enum.member?(@profile_permissions, :self) and
                Enum.member?(@profile_permissions, :friend)
            }
            url={~p"/profile/#{@userid}/relationships"}
            selected={@tab == "relationships"}
          >
            <Fontawesome.icon icon={Teiserver.Account.RelationshipLib.icon()} style="solid" />
            Relationships
          </.tab_nav>

          <.tab_nav
            :if={Enum.member?(@profile_permissions, :self) and allow?(@current_user, "BAR+")}
            url={~p"/profile/#{@userid}/contributor"}
            selected={@tab == "contributor"}
          >
            <Fontawesome.icon icon="fa-code-commit" style="solid" /> Contributor
          </.tab_nav>
        </.tab_header>
      </div>
    </div>
    """
  end

  @doc """
  <TeiserverWeb.Account.ProfileComponents.profile_header
    active="overview"
    view_colour={@view_colour}
    user={@user}
    current_user={@current_user}
  />
  """
  attr :active, :string, required: true
  attr :view_colour, :atom, required: true
  attr :user, :map, required: true
  attr :current_user, :map, default: nil
  attr :profile_permissions, :list, default: []

  def profile_header(assigns) do
    ~H"""
    <TeiserverWeb.AccountComponents.sub_menu active="profile" view_colour={@view_colour} />

    <div class="row mt-2">
      <div class="col">
        <h3 class="mb-4 py-1" style={"background-color: #{@user.colour};"}>
          <div class="d-inline-block px-2 py-1 mx-1">
            <Fontawesome.icon icon={@user.icon} style="regular" size="sm" />
          </div>

          <%= @user.name %> &nbsp;&nbsp;&nbsp;&nbsp;
          <span style="font-size: 0.7em;">
            Chevron level: <%= (@user.rank || 0) + 1 %>
          </span>
        </h3>
      </div>
    </div>

    <TeiserverWeb.Account.ProfileComponents.profile_tabs
      tab={@active}
      userid={@user.id}
      profile_permissions={@profile_permissions}
      current_user={@current_user}
    />
    """
  end
end
