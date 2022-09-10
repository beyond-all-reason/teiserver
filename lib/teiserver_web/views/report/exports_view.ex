defmodule TeiserverWeb.Report.ExportsView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :success2

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-download"
end
