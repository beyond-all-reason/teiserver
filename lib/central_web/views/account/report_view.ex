defmodule CentralWeb.Account.ReportView do
  use CentralWeb, :view

  @spec view_colour :: {String.t(), String.t(), String.t()}
  def view_colour(), do: Central.Account.ReportLib.colours()

  @spec icon :: String.t()
  def icon(), do: Central.Account.ReportLib.icon()
end
