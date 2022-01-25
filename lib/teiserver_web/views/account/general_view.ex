defmodule TeiserverWeb.Account.GeneralView do
  use TeiserverWeb, :view

  def colours(), do: StylingHelper.colours(:success)
  def icon(), do: "fas fa-user"

  def colours("relationships"), do: StylingHelper.colours(:info)
  def colours("customisation"), do: Central.Config.UserConfigLib.colours()
  def colours("preferences"), do: Central.Config.UserConfigLib.colours()
  def colours("clans"), do: Teiserver.Clans.ClanLib.colours()
end
