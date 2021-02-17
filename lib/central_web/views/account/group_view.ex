defmodule CentralWeb.Account.GroupView do
  use CentralWeb, :view

  def colours, do: Central.Account.GroupLib.colours()
  def icon, do: Central.Account.GroupLib.icon()
  def name, do: "group"
end
