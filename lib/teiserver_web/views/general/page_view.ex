defmodule TeiserverWeb.General.PageView do
  use TeiserverWeb, :view

  def view_colour(), do: Teiserver.Helper.StylingHelper.colours(:default)
  # def icon(), do: Central.Universe.icon()

  def view_colour("home"), do: view_colour()
  def view_colour("account"), do: view_colour()
  def view_colour("user_configs"), do: Teiserver.Config.UserConfigLib.colours()
end
