defmodule TeiserverWeb.Components.Admin.MatchComponents do
  @moduledoc """
  Components for Match pages
  """
  alias Teiserver.Account.User

  use TeiserverWeb, :component
  import TeiserverWeb.NavComponents, only: [section_menu_button: 1]

  @doc """
  <TeiserverWeb.Components.Admin.MatchComponents.section_menu active={active} colour={} />
  """
  attr :current_user, User, required: true
  attr :colour, :string, required: true
  attr :active, :string, required: true

  def section_menu(assigns) do
    ~H"""
    <.section_menu_button
      :if={allow?(@current_user, "Reviewer")}
      active={@active == "index"}
      icon="fa-solid fa-bars"
      bsname={@colour}
      url={~p"/teiserver/admin/matches"}
    >
      List
    </.section_menu_button>

    <.section_menu_button
      active={@active == "new"}
      icon="fa-solid fa-search"
      bsname={@colour}
      url={~p"/teiserver/admin/matches?search=true"}
    >
      Search
    </.section_menu_button>
    """
  end
end
