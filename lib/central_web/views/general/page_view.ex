defmodule CentralWeb.General.PageView do
  use CentralWeb, :view

  def view_colour(), do: Central.Helpers.StylingHelper.colours(:default)
  # def icon(), do: Central.Universe.icon()

  def view_colour("home"), do: view_colour()
  def view_colour("account"), do: view_colour()
  def view_colour("user_configs"), do: Central.Config.UserConfigLib.colours()
end
