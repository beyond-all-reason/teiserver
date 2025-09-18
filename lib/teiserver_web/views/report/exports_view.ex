defmodule TeiserverWeb.Report.ExportsView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :info

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-download"
end
