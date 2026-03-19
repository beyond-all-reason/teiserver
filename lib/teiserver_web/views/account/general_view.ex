defmodule TeiserverWeb.Account.GeneralView do
  use TeiserverWeb, :view

  alias Teiserver.Clans.ClanLib
  alias Teiserver.Config.UserConfigLib
  alias Teiserver.Game.AchievementTypeLib

  @spec view_colour :: atom
  def view_colour(), do: :success

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-user"

  @spec view_colour(String.t()) :: atom
  def view_colour("profile"), do: :primary
  def view_colour("relationships"), do: :info
  def view_colour("customisation"), do: UserConfigLib.colours()
  def view_colour("preferences"), do: UserConfigLib.colours()
  def view_colour("clans"), do: ClanLib.colours()
  def view_colour("achievements"), do: AchievementTypeLib.colour()

  def view_colour("details"), do: :primary
  def view_colour("security"), do: :danger
end
