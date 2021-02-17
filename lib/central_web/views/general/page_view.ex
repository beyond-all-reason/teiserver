defmodule CentralWeb.General.PageView do
  use CentralWeb, :view

  def colours(), do: Central.Helpers.StylingHelper.colours(:default)
  # def icon(), do: Central.Universe.icon()

  def colours("home"), do: colours()
  def colours("account"), do: colours()
  def colours("user_configs"), do: Central.Config.UserConfigLib.colours()
end
