defmodule BarserverWeb.General.PageView do
  use BarserverWeb, :view

  def view_colour(), do: Barserver.Helper.StylingHelper.colours(:default)

  def view_colour("home"), do: view_colour()
  def view_colour("account"), do: view_colour()
  def view_colour("user_configs"), do: Barserver.Config.UserConfigLib.colours()
end
