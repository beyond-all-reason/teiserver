defmodule CentralWeb.Account.ReportView do
  use CentralWeb, :view

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours(), do: Central.Account.ReportLib.colours()
  @spec icon :: String.t()
  def icon(), do: Central.Account.ReportLib.icon()
end
