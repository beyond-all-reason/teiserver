defmodule TeiserverWeb.Account.GeneralView do
  use TeiserverWeb, :view

  def colours(), do: StylingHelper.colours(:success)
  def icon(), do: StylingHelper.icon(:success)

  def colours("relationships"), do: StylingHelper.colours(:info)
  def colours("preferences"), do: Central.Config.UserConfigLib.colours()
  def colours("clans"), do: Teiserver.Clans.ClanLib.colours()
end
