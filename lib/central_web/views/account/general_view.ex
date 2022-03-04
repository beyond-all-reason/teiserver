defmodule CentralWeb.Account.GeneralView do
  use CentralWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :info2

  @spec view_colour(String.t()) :: atom
  def view_colour("groups"), do: Central.Account.GroupLib.colours()
  def view_colour("user_configs"), do: Central.Config.UserConfigLib.colours()
  def view_colour("reports"), do: Central.Account.ReportLib.colours()
  def view_colour("details"), do: :primary
  def view_colour("password"), do: :success2
end
