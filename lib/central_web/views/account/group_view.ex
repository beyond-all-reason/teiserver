defmodule CentralWeb.Account.GroupView do
  use CentralWeb, :view

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Account.GroupLib.colours()

  @spec icon :: String.t()
  def icon, do: Central.Account.GroupLib.icon()

  @spec name :: String.t()
  def name, do: "group"
end
