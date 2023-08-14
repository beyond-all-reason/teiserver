defmodule TeiserverWeb.Account.ProfileComponents do
  @moduledoc false
  use CentralWeb, :component
  import TeiserverWeb.NavComponents, only: [tab_header: 1, tab_nav: 1]

  @doc """
  <TeiserverWeb.Account.ProfileComponents.profile_tabs tab="overview" userid={@userid} self={@current_user && @current_user.id == @userid} />
  """
  attr :tab, :string, required: true
  attr :userid, :integer, required: true
  attr :self, :boolean, default: false
  def profile_tabs(assigns) do
    ~H"""
    <div class="row mt-2 mb-3">
      <div class="col" id="nav-col">
        <.tab_header>
          <.tab_nav
            url={~p"/profile/#{@userid}/overview"}
            selected={@tab == "overview"}
          >
            <Fontawesome.icon icon_atom={:summary} style="solid" />
            Overview
          </.tab_nav>

          <.tab_nav
            url={~p"/profile/#{@userid}/accolades"}
            selected={@tab == "accolades"}
          >
            <Fontawesome.icon icon={Teiserver.Account.AccoladeLib.icon()} style="solid" />
            Accolades
          </.tab_nav>

          <.tab_nav
            url={~p"/profile/#{@userid}/achievements"}
            selected={@tab == "achievements"}
          >
            <Fontawesome.icon icon={Teiserver.Game.AchievementTypeLib.icon()} style="solid" />
            Achievements
          </.tab_nav>

          <%= if @self do %>
            <%!-- Stuff here --%>
          <% end %>
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

  def profile_header(assigns) do
    ~H"""
    <TeiserverWeb.AccountComponents.sub_menu active="profile" view_colour={@view_colour} />

    <div class="row mt-2 mb-3">
      <div class="col">
        <h4><%= @user.name %></h4>
      </div>
    </div>

    <TeiserverWeb.Account.ProfileComponents.profile_tabs tab={@active} userid={@user.id} self={@current_user && @current_user.id == @user.id} />
    """
  end
end
