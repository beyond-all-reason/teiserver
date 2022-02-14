defmodule CentralWeb.Account.GeneralView do
  use CentralWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :info2

  @spec view_colour(String.t()) :: {String.t(), String.t(), String.t()}
  def view_colour("groups"), do: Central.Account.GroupLib.colours()
  def view_colour("user_configs"), do: Central.Config.UserConfigLib.colours()
  def view_colour("reports"), do: Central.Account.ReportLib.colours()
end
