defmodule CentralWeb.Account.GroupView do
  use CentralWeb, :view

  @spec view_colour :: {String.t(), String.t(), String.t()}
  def view_colour, do: Central.Account.GroupLib.colours()

  @spec icon :: String.t()
  def icon, do: Central.Account.GroupLib.icon()

  @spec name :: String.t()
  def name, do: "group"
end
