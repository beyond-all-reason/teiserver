defmodule CentralWeb.Admin.CodeView do
  use CentralWeb, :view

  @spec view_colour() :: {String.t(), String.t(), String.t()}
  def view_colour(), do: Central.Account.CodeLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Central.Account.CodeLib.icon()
end
